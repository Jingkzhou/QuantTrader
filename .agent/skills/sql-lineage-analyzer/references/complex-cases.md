# 复杂场景解析策略

本文档描述自动解析可能失败的复杂场景及处理策略。

## 目录
- [动态 SQL](#动态-sql)
- [存储过程控制流](#存储过程控制流)
- [临时表和变量](#临时表和变量)
- [隐式类型转换](#隐式类型转换)
- [LLM 辅助策略](#llm-辅助策略)

---

## 动态 SQL

### 场景描述
```sql
-- Oracle
EXECUTE IMMEDIATE 'INSERT INTO ' || v_table_name || ' SELECT * FROM source';

-- MySQL
SET @sql = CONCAT('SELECT * FROM ', table_name);
PREPARE stmt FROM @sql;
EXECUTE stmt;
```

### 解析策略
1. **静态分析标记**: 检测到动态 SQL 时，标记 `confidence: 0.3`
2. **模式匹配**: 尝试从字符串拼接中提取表名模式
3. **LLM 辅助**: 提交给 LLM 分析可能的表名范围
4. **人工标注**: 生成 `[需复核]` 标记

### 输出示例
```json
{
  "statement_type": "DYNAMIC",
  "target_table": null,
  "source_tables": [],
  "confidence": 0.3,
  "warnings": ["检测到动态 SQL，无法静态分析目标表"],
  "llm_suggestion": "根据变量命名 v_table_name 推测目标表可能为业务表"
}
```

---

## 存储过程控制流

### 场景描述
```sql
IF condition THEN
    INSERT INTO table_a SELECT * FROM source;
ELSE
    INSERT INTO table_b SELECT * FROM source;
END IF;
```

### 解析策略
1. **分支合并**: 将所有分支的血缘合并（保守策略）
2. **条件标注**: 在输出中标注条件依赖
3. **分支拆分**: 可选输出每个分支的独立血缘

### 输出示例
```json
{
  "branches": [
    {
      "condition": "condition = TRUE",
      "target_table": "table_a",
      "source_tables": ["source"]
    },
    {
      "condition": "condition = FALSE", 
      "target_table": "table_b",
      "source_tables": ["source"]
    }
  ],
  "merged_targets": ["table_a", "table_b"],
  "merged_sources": ["source"]
}
```

---

## 临时表和变量

### 场景描述
```sql
CREATE TEMPORARY TABLE temp_data AS SELECT * FROM source1;

INSERT INTO target
SELECT t.col1, s.col2 
FROM temp_data t JOIN source2 s ON t.id = s.id;

DROP TEMPORARY TABLE temp_data;
```

### 解析策略
1. **临时表追踪**: 维护临时表的定义和血缘
2. **血缘展开**: 将临时表替换为其原始源表
3. **作用域感知**: 识别临时表的生命周期

### 输出示例
```json
{
  "statement_type": "INSERT",
  "target_table": "target",
  "source_tables": ["source1", "source2"],
  "intermediate_tables": [
    {
      "name": "temp_data",
      "type": "TEMPORARY",
      "sources": ["source1"]
    }
  ],
  "warnings": ["已展开临时表 temp_data 的血缘"]
}
```

---

## 隐式类型转换

### 场景描述
```sql
SELECT 
    CAST(a.date_str AS DATE) as order_date,
    a.amount + b.adjustment as total
FROM table_a a JOIN table_b b ON a.id = b.id;
```

### 解析策略
1. **类型转换识别**: 检测 CAST, CONVERT 等函数
2. **隐式转换警告**: 当表达式涉及不同类型时提示
3. **transform_type 细化**: 区分 TYPE_CAST 和 EXPRESSION

---

## LLM 辅助策略

当静态解析置信度 < 0.7 时，可使用 LLM 辅助分析。

### Prompt 模板
```
分析以下 SQL 存储过程的数据血缘关系：

```sql
{sql_code}
```

请识别：
1. 所有源表和目标表
2. 字段级的转换关系
3. 任何动态 SQL 或条件分支

输出 JSON 格式：
{schema}
```

### 使用时机
- 检测到 EXECUTE IMMEDIATE / PREPARE
- 复杂的字符串拼接
- 多层嵌套存储过程调用
- 置信度 < 0.7 的解析结果

### 结果合并
```json
{
  "static_analysis": { ... },
  "llm_analysis": { ... },
  "merged_result": { ... },
  "merge_strategy": "UNION",
  "confidence": 0.85
}
```

---

## 最佳实践

1. **保守合并**: 宁可多识别源表，不要漏掉
2. **置信度透明**: 始终输出置信度和警告
3. **增量验证**: 对比新旧版本时高亮差异
4. **人工复核**: 低置信度结果标记待复核
