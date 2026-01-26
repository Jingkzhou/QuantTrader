#!/usr/bin/env python3
"""
血缘可视化工具 - 生成 Mermaid 图
"""

import json
import sys
from typing import Union


def generate_mermaid_table_level(lineage_data: Union[dict, list]) -> str:
    """
    生成表级血缘 Mermaid 图

    Args:
        lineage_data: 血缘 JSON 数据（单条或列表）

    Returns:
        Mermaid 图代码
    """
    lines = ["graph LR"]
    edges = set()

    if isinstance(lineage_data, dict):
        lineage_data = [lineage_data]

    for item in lineage_data:
        target = item.get("target_table") or "RESULT"
        sources = item.get("source_tables", [])
        stmt_type = item.get("statement_type", "")

        # 清理表名用于节点 ID
        target_id = target.replace(".", "_").replace("-", "_")

        for src in sources:
            src_id = src.replace(".", "_").replace("-", "_")
            edge = f'    {src_id}["{src}"] --> |{stmt_type}| {target_id}["{target}"]'
            edges.add(edge)

    lines.extend(sorted(edges))

    # 添加样式
    lines.append("")
    lines.append("    %% 样式定义")
    lines.append("    classDef source fill:#e1f5fe,stroke:#01579b")
    lines.append("    classDef target fill:#fff3e0,stroke:#e65100")

    return "\n".join(lines)


def generate_mermaid_column_level(lineage_data: Union[dict, list]) -> str:
    """
    生成字段级血缘 Mermaid 图

    Args:
        lineage_data: 血缘 JSON 数据

    Returns:
        Mermaid 图代码
    """
    lines = ["graph LR"]
    subgraphs = {}
    edges = []

    if isinstance(lineage_data, dict):
        lineage_data = [lineage_data]

    for item in lineage_data:
        target_table = item.get("target_table") or "RESULT"

        for col in item.get("column_lineages", []):
            src_table = col.get("source_table", "UNKNOWN")
            src_col = col.get("source_column")
            tgt_col = col.get("target_column")
            transform = col.get("transform_type", "")

            # 添加到子图
            if src_table not in subgraphs:
                subgraphs[src_table] = []
            subgraphs[src_table].append(src_col)

            if target_table not in subgraphs:
                subgraphs[target_table] = []
            if tgt_col not in subgraphs[target_table]:
                subgraphs[target_table].append(tgt_col)

            # 添加边
            src_id = f"{src_table}_{src_col}".replace(".", "_").replace("-", "_")
            tgt_id = f"{target_table}_{tgt_col}".replace(".", "_").replace("-", "_")

            if transform == "DIRECT":
                edges.append(f"    {src_id} --> {tgt_id}")
            else:
                edges.append(f"    {src_id} --> |{transform}| {tgt_id}")

    # 生成子图
    for table, cols in subgraphs.items():
        table_id = table.replace(".", "_").replace("-", "_")
        lines.append(f'    subgraph {table_id}["{table}"]')
        for col in set(cols):
            col_id = f"{table}_{col}".replace(".", "_").replace("-", "_")
            lines.append(f'        {col_id}["{col}"]')
        lines.append("    end")
        lines.append("")

    # 添加边
    lines.extend(edges)

    # 样式
    lines.append("")
    lines.append("    %% 样式")
    lines.append("    classDef transform fill:#fff9c4,stroke:#f57f17")

    return "\n".join(lines)


def generate_impact_analysis(lineage_data: list, changed_table: str) -> dict:
    """
    生成影响分析报告

    Args:
        lineage_data: 血缘数据列表
        changed_table: 发生变更的表名

    Returns:
        影响分析结果
    """
    # 构建依赖图
    downstream = {}  # table -> [dependent tables]
    upstream = {}  # table -> [source tables]

    for item in lineage_data:
        target = item.get("target_table")
        sources = item.get("source_tables", [])

        if target:
            upstream[target] = sources
            for src in sources:
                if src not in downstream:
                    downstream[src] = []
                downstream[src].append(target)

    # 查找下游影响
    def find_downstream(table, visited=None):
        if visited is None:
            visited = set()
        if table in visited:
            return []
        visited.add(table)

        result = []
        for dep in downstream.get(table, []):
            result.append(dep)
            result.extend(find_downstream(dep, visited))
        return result

    # 查找上游依赖
    def find_upstream(table, visited=None):
        if visited is None:
            visited = set()
        if table in visited:
            return []
        visited.add(table)

        result = []
        for src in upstream.get(table, []):
            result.append(src)
            result.extend(find_upstream(src, visited))
        return result

    affected = find_downstream(changed_table)
    dependencies = find_upstream(changed_table)

    return {
        "changed_table": changed_table,
        "direct_downstream": downstream.get(changed_table, []),
        "all_affected": list(set(affected)),
        "affected_count": len(set(affected)),
        "dependencies": list(set(dependencies)),
        "risk_level": (
            "HIGH" if len(affected) > 5 else "MEDIUM" if len(affected) > 2 else "LOW"
        ),
    }


def main():
    """命令行入口"""
    if len(sys.argv) < 2:
        print("用法:")
        print("  python visualize_lineage.py <lineage_json> [table|column]")
        print("  python visualize_lineage.py <lineage_json> impact <table_name>")
        sys.exit(1)

    json_file = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) > 2 else "table"

    with open(json_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    if mode == "impact" and len(sys.argv) > 3:
        table_name = sys.argv[3]
        result = generate_impact_analysis(
            data if isinstance(data, list) else [data], table_name
        )
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif mode == "column":
        print(generate_mermaid_column_level(data))
    else:
        print(generate_mermaid_table_level(data))


if __name__ == "__main__":
    main()
