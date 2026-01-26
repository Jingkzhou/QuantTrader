# 项目工具映射表 (Banking Systems)

在 `agent/crews.py` 组装 Crew 时，请确保为每个专家注入正确的工具集。

| 系统 (Agent)   | 数据库工具获取函数         | 知识库工具获取函数     | 通用工具                                |
| :------------- | :------------------------- | :--------------------- | :-------------------------------------- |
| **1104系统**   | `get_1104_tools()`         | `get_1104_rag_tools()` | `get_sql_tool()`, `get_lineage_tools()` |
| **大集中系统** | `get_core_banking_tools()` | `get_core_rag_tools()` | `get_sql_tool()`, `get_lineage_tools()` |
| **EAST系统**   | `get_east_tools()`         | `get_east_rag_tools()` | `get_sql_tool()`, `get_lineage_tools()` |
| **一表通系统** | `get_ybt_tools()`          | `get_ybt_rag_tools()`  | `get_sql_tool()`, `get_lineage_tools()` |

## 导入路径参考
- `from agent.tools import get_sql_tool, get_lineage_tools`
- `from agent.tools.banking_tools import ...`
