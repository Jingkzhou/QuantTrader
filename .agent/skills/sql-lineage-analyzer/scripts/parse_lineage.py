#!/usr/bin/env python3
"""
SQL 血缘解析器 - 基于 sqlglot 实现多方言 SQL 血缘分析
支持 MySQL, Oracle, Hive
"""

import json
import sys
import hashlib
from dataclasses import dataclass, field, asdict
from typing import Optional
from enum import Enum

try:
    import sqlglot
    from sqlglot import exp
    from sqlglot.lineage import lineage
except ImportError:
    print("错误: 需要安装 sqlglot 库", file=sys.stderr)
    print("运行: pip install sqlglot", file=sys.stderr)
    sys.exit(1)


class TransformType(str, Enum):
    """字段转换类型"""

    DIRECT = "DIRECT"  # 直接映射
    EXPRESSION = "EXPRESSION"  # 表达式计算
    AGGREGATE = "AGGREGATE"  # 聚合函数
    CASE_WHEN = "CASE_WHEN"  # 条件逻辑
    WINDOW = "WINDOW"  # 窗口函数
    UNKNOWN = "UNKNOWN"  # 未知


@dataclass
class ColumnLineage:
    """字段级血缘"""

    source_table: str
    source_column: str
    target_column: str
    transform_type: str
    expression: Optional[str] = None
    confidence: float = 1.0


@dataclass
class TableLineage:
    """表级血缘"""

    source_tables: list[str] = field(default_factory=list)
    target_table: Optional[str] = None
    statement_type: str = "SELECT"
    column_lineages: list[ColumnLineage] = field(default_factory=list)
    sql_hash: str = ""
    confidence: float = 1.0
    warnings: list[str] = field(default_factory=list)


DIALECT_MAP = {
    "mysql": "mysql",
    "oracle": "oracle",
    "hive": "hive",
    "spark": "spark",
    "presto": "presto",
    "trino": "trino",
}


def detect_statement_type(parsed) -> str:
    """检测 SQL 语句类型"""
    if isinstance(parsed, exp.Insert):
        return "INSERT"
    elif isinstance(parsed, exp.Update):
        return "UPDATE"
    elif isinstance(parsed, exp.Delete):
        return "DELETE"
    elif isinstance(parsed, exp.Merge):
        return "MERGE"
    elif isinstance(parsed, exp.Create):
        return "CREATE"
    elif isinstance(parsed, exp.Select):
        return "SELECT"
    return "UNKNOWN"


def _get_table_fullname(table: exp.Table) -> str:
    """获取表的完整名称（含 schema/database）"""
    name = table.name
    if table.db:
        name = f"{table.db}.{name}"
    return name


def extract_tables(parsed) -> tuple[list[str], Optional[str]]:
    """提取源表和目标表"""
    source_tables = []
    target_table = None

    # 先识别目标表（INSERT/UPDATE/MERGE/CREATE 的直接目标）
    if isinstance(parsed, exp.Insert):
        # INSERT INTO 的目标表可能是 Table 或 Schema（带列名时）
        target_node = parsed.this
        if isinstance(target_node, exp.Schema):
            # INSERT INTO table (col1, col2) 形式
            target_node = target_node.this
        if isinstance(target_node, exp.Table):
            target_table = _get_table_fullname(target_node)
    elif isinstance(parsed, exp.Update):
        # UPDATE 的目标表
        if parsed.this and isinstance(parsed.this, exp.Table):
            target_table = _get_table_fullname(parsed.this)
    elif isinstance(parsed, exp.Create):
        # CREATE TABLE 的目标表可能是 Table 或 Schema
        target_node = parsed.this
        if isinstance(target_node, exp.Schema):
            target_node = target_node.this
        if isinstance(target_node, exp.Table):
            target_table = _get_table_fullname(target_node)
    elif isinstance(parsed, exp.Merge):
        # MERGE INTO 的目标表
        if parsed.this and isinstance(parsed.this, exp.Table):
            target_table = _get_table_fullname(parsed.this)

    # 收集所有表引用作为源表（排除目标表）
    for table in parsed.find_all(exp.Table):
        table_name = _get_table_fullname(table)
        # 排除目标表
        if table_name != target_table:
            source_tables.append(table_name)

    return list(set(source_tables)), target_table


def build_alias_map(parsed) -> dict[str, str]:
    """
    构建表别名到完整表名的映射

    Returns:
        {alias: full_table_name} 字典，例如 {'o': 'ods.orders', 'p': 'dim.product'}
    """
    alias_map = {}

    for table in parsed.find_all(exp.Table):
        full_name = _get_table_fullname(table)
        alias = table.alias

        if alias:
            # 有别名时，建立映射
            alias_map[alias] = full_name
        else:
            # 无别名时，表名本身也可作为引用
            alias_map[table.name] = full_name
            alias_map[full_name] = full_name

    return alias_map


def classify_expression(expr) -> str:
    """分类表达式类型"""
    expr_sql = expr.sql() if hasattr(expr, "sql") else str(expr)

    if isinstance(expr, exp.Column):
        return TransformType.DIRECT.value
    elif isinstance(expr, exp.AggFunc):
        return TransformType.AGGREGATE.value
    elif isinstance(expr, exp.Case):
        return TransformType.CASE_WHEN.value
    elif isinstance(expr, exp.Window):
        return TransformType.WINDOW.value
    elif isinstance(expr, (exp.Binary, exp.Func)):
        return TransformType.EXPRESSION.value
    return TransformType.UNKNOWN.value


def extract_column_lineage(
    parsed, dialect: str, alias_map: dict[str, str] = None
) -> list[ColumnLineage]:
    """
    提取字段级血缘

    Args:
        parsed: 解析后的 AST
        dialect: SQL 方言
        alias_map: 别名到完整表名的映射
    """
    column_lineages = []
    alias_map = alias_map or {}

    # 查找 SELECT 子句
    for select in parsed.find_all(exp.Select):
        for i, expr in enumerate(select.expressions):
            # 获取目标列名
            if isinstance(expr, exp.Alias):
                target_col = expr.alias
                source_expr = expr.this
            elif isinstance(expr, exp.Column):
                target_col = expr.name
                source_expr = expr
            else:
                target_col = f"col_{i}"
                source_expr = expr

            # 提取源列并去重
            seen_sources = set()
            transform_type = classify_expression(source_expr)

            for src_col in source_expr.find_all(exp.Column):
                table_ref = src_col.table or "UNKNOWN"
                source_key = (table_ref, src_col.name)
                if source_key in seen_sources:
                    continue
                seen_sources.add(source_key)

                # 将别名解析为完整表名
                table_name = alias_map.get(table_ref, table_ref)
                column_lineages.append(
                    ColumnLineage(
                        source_table=table_name,
                        source_column=src_col.name,
                        target_column=target_col,
                        transform_type=transform_type,
                        expression=(
                            source_expr.sql()
                            if transform_type != TransformType.DIRECT.value
                            else None
                        ),
                    )
                )

    return column_lineages


def parse_sql(sql: str, dialect: str = "mysql") -> TableLineage:
    """
    解析 SQL 语句，提取血缘关系

    Args:
        sql: SQL 语句
        dialect: 数据库方言 (mysql, oracle, hive)

    Returns:
        TableLineage 对象
    """
    result = TableLineage()
    result.sql_hash = hashlib.md5(sql.encode()).hexdigest()[:12]

    # 标准化方言名称
    dialect = DIALECT_MAP.get(dialect.lower(), "mysql")

    try:
        # 解析 SQL
        parsed = sqlglot.parse_one(sql, dialect=dialect)

        # 检测语句类型
        result.statement_type = detect_statement_type(parsed)

        # 提取表
        sources, target = extract_tables(parsed)
        result.source_tables = sources
        result.target_table = target

        # 构建别名映射
        alias_map = build_alias_map(parsed)

        # 提取字段级血缘（传入别名映射）
        result.column_lineages = extract_column_lineage(parsed, dialect, alias_map)

    except Exception as e:
        result.warnings.append(f"解析警告: {str(e)}")
        result.confidence = 0.5

    return result


def parse_procedure(procedure_sql: str, dialect: str = "mysql") -> list[TableLineage]:
    """
    解析存储过程，拆分为多个 SQL 语句后逐一分析

    Args:
        procedure_sql: 存储过程代码
        dialect: 数据库方言

    Returns:
        TableLineage 列表
    """
    results = []
    dialect = DIALECT_MAP.get(dialect.lower(), "mysql")

    try:
        # 使用 sqlglot 解析多语句
        statements = sqlglot.parse(procedure_sql, dialect=dialect)

        for stmt in statements:
            if stmt:
                result = parse_sql(stmt.sql(dialect=dialect), dialect)
                results.append(result)

    except Exception as e:
        # 降级：按分号拆分
        for sql in procedure_sql.split(";"):
            sql = sql.strip()
            if sql and not sql.upper().startswith(
                ("DECLARE", "SET", "IF", "WHILE", "BEGIN", "END")
            ):
                result = parse_sql(sql, dialect)
                result.warnings.append(f"降级解析: {str(e)}")
                results.append(result)

    filtered_results = []
    for res in results:
        # 1. 必须有 source 或 target
        if not res.source_tables and not res.target_table:
            continue

        # 2. 过滤掉无目标表的 SELECT (通常是 SELECT INTO 变量)
        if res.statement_type == "SELECT" and not res.target_table:
            continue

        # 3. 过滤 UNKNOWN 类型 (通常是 PL/SQL 赋值或控制流)
        if res.statement_type == "UNKNOWN":
            continue

        # 4. 过滤置信度过低的结果
        if res.confidence < 0.5:
            continue

        filtered_results.append(res)

    return filtered_results


def compare_lineage(old: TableLineage, new: TableLineage) -> dict:
    """
    比较两个血缘结果，返回差异

    Args:
        old: 旧版本血缘
        new: 新版本血缘

    Returns:
        差异描述
    """
    diff = {
        "hash_changed": old.sql_hash != new.sql_hash,
        "added_sources": list(set(new.source_tables) - set(old.source_tables)),
        "removed_sources": list(set(old.source_tables) - set(new.source_tables)),
        "target_changed": old.target_table != new.target_table,
        "column_changes": [],
    }

    # 比较字段血缘
    old_cols = {
        (c.source_table, c.source_column, c.target_column) for c in old.column_lineages
    }
    new_cols = {
        (c.source_table, c.source_column, c.target_column) for c in new.column_lineages
    }

    diff["added_columns"] = [
        {"source": f"{c[0]}.{c[1]}", "target": c[2]} for c in new_cols - old_cols
    ]
    diff["removed_columns"] = [
        {"source": f"{c[0]}.{c[1]}", "target": c[2]} for c in old_cols - new_cols
    ]

    return diff


def to_json(lineage: TableLineage) -> str:
    """将血缘结果转为 JSON"""
    data = {
        "statement_type": lineage.statement_type,
        "target_table": lineage.target_table,
        "source_tables": lineage.source_tables,
        "column_lineages": [asdict(c) for c in lineage.column_lineages],
        "sql_hash": lineage.sql_hash,
        "confidence": lineage.confidence,
        "warnings": lineage.warnings,
    }
    return json.dumps(data, ensure_ascii=False, indent=2)


def main():
    """命令行入口"""
    if len(sys.argv) < 2:
        print("用法: python parse_lineage.py <sql_file> [dialect]")
        print("方言: mysql, oracle, hive")
        sys.exit(1)

    sql_file = sys.argv[1]
    dialect = sys.argv[2] if len(sys.argv) > 2 else "mysql"

    with open(sql_file, "r", encoding="utf-8") as f:
        sql = f.read()

    # 判断是单条 SQL 还是存储过程
    if "CREATE PROCEDURE" in sql.upper() or "CREATE OR REPLACE" in sql.upper():
        results = parse_procedure(sql, dialect)
        output = [json.loads(to_json(r)) for r in results]
    else:
        result = parse_sql(sql, dialect)
        output = json.loads(to_json(result))

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
