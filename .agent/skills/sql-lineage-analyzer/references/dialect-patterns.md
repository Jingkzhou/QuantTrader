# SQL 方言特殊模式参考

本文档记录 MySQL、Oracle、Hive 的特殊语法及解析策略。

## 目录
- [MySQL 特殊模式](#mysql-特殊模式)
- [Oracle 特殊模式](#oracle-特殊模式)
- [Hive 特殊模式](#hive-特殊模式)
- [通用复杂场景](#通用复杂场景)

---

## MySQL 特殊模式

### INSERT ... ON DUPLICATE KEY UPDATE
```sql
INSERT INTO target_table (col1, col2)
SELECT a.col1, a.col2 FROM source_table a
ON DUPLICATE KEY UPDATE col2 = VALUES(col2);
```
**解析策略**: 同时识别 INSERT 和 UPDATE 的血缘关系

### REPLACE INTO
```sql
REPLACE INTO target_table SELECT * FROM source_table;
```
**解析策略**: 等同于 DELETE + INSERT，标记为 REPLACE 类型

### 多表 UPDATE
```sql
UPDATE t1, t2 SET t1.col = t2.col WHERE t1.id = t2.id;
```
**解析策略**: t2 为源表，t1 为目标表

---

## Oracle 特殊模式

### MERGE INTO
```sql
MERGE INTO target t
USING source s ON (t.id = s.id)
WHEN MATCHED THEN UPDATE SET t.col = s.col
WHEN NOT MATCHED THEN INSERT (id, col) VALUES (s.id, s.col);
```
**解析策略**: 识别 USING 子句为源表，INTO 为目标表

### INSERT ALL / INSERT FIRST
```sql
INSERT ALL
  INTO table1 (col) VALUES (val1)
  INTO table2 (col) VALUES (val2)
SELECT ... FROM source_table;
```
**解析策略**: 多个目标表，需分别记录

### WITH 子句 (CTE)
```sql
WITH temp AS (SELECT * FROM source1)
INSERT INTO target SELECT * FROM temp JOIN source2 ON ...;
```
**解析策略**: CTE 展开为源表列表

### 分析函数
```sql
SELECT col1, SUM(col2) OVER (PARTITION BY col3) as running_sum
FROM source_table;
```
**解析策略**: 标记 transform_type 为 WINDOW

---

## Hive 特殊模式

### INSERT OVERWRITE
```sql
INSERT OVERWRITE TABLE target_table PARTITION (dt='2024-01-01')
SELECT col1, col2 FROM source_table WHERE dt = '2024-01-01';
```
**解析策略**: 等同于 TRUNCATE + INSERT，标记为 INSERT_OVERWRITE

### CTAS (CREATE TABLE AS SELECT)
```sql
CREATE TABLE new_table AS
SELECT a.col1, b.col2 FROM table_a a JOIN table_b b ON a.id = b.id;
```
**解析策略**: 目标表为新创建的表，语句类型为 CREATE

### 动态分区
```sql
INSERT INTO TABLE target PARTITION (year, month)
SELECT col1, col2, year, month FROM source;
```
**解析策略**: 分区列也纳入字段血缘

### LATERAL VIEW
```sql
SELECT id, item FROM source_table
LATERAL VIEW explode(items) t AS item;
```
**解析策略**: explode 产生的列标记为 EXPRESSION 类型

---

## 通用复杂场景

### 子查询
```sql
SELECT * FROM (
    SELECT a.col1, b.col2 
    FROM table_a a JOIN table_b b ON a.id = b.id
) sub;
```
**解析策略**: 递归解析子查询，合并血缘

### UNION / UNION ALL
```sql
SELECT col FROM table_a
UNION ALL
SELECT col FROM table_b;
```
**解析策略**: 两个分支的源表都纳入

### CASE WHEN
```sql
SELECT 
    CASE WHEN a.type = 1 THEN b.value1 ELSE c.value2 END as result
FROM table_a a
JOIN table_b b ON a.id = b.id
JOIN table_c c ON a.id = c.id;
```
**解析策略**: 所有分支涉及的列都标记为源，transform_type 为 CASE_WHEN

### 多层嵌套
```sql
WITH cte1 AS (...),
     cte2 AS (SELECT ... FROM cte1)
INSERT INTO target
SELECT * FROM cte2 JOIN source ON ...;
```
**解析策略**: 递归展开 CTE 依赖链
