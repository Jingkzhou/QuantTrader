---
name: crewai-orchestrator
description: 专门用于在 urgs 项目中添加、修改或优化 CrewAI Agent 和 Task 的技能。当用户要求“添加新系统专家”、“修改 Agent 行为”或“优化 CrewAI 工作流”时触发。它确保所有变更符合项目的中心化 PM 架构、SOTA 协议和工具注入规范。
---

# CrewAI Orchestrator

本技能旨在规范 `urgs` 项目中 CrewAI 组件的扩展流程。它包含了 Agent、Task 和 Crew 的纵向延伸逻辑。

## 核心工作流

### 1. 调研与定位
在添加新 Agent 之前，必须确定其归属系统及所需工具：
- 查看 `agent/tools/` 下是否有现成的工具集。
- 确认该 Agent 在 `agent/crews.py` 的 `create_unified_crew` 中的整合位置。

### 2. 定义 Agent (`agent/agents.py`)
- **角色定位**：遵循 [agent_patterns.md](references/agent_patterns.md) 中的模板。
- **SOTA 协议**：确保 Backstory 包含工具使用准则和事实核查要求。
- **LLM 选择**：协调员使用 `get_primary_llm()`，专家使用 `get_secondary_llm()`。

### 3. 定义 Task (`agent/tasks.py`)
- **任务解析**：遵循 [task_patterns.md](references/task_patterns.md) 中的 CoT (Think/Plan/Delegate) 模式。
- **证据导向**：明确 `expected_output` 必须基于查到的真实证据，禁止猜测。

### 4. 组装 Crew (`agent/crews.py`)
- **工具注入**：参考 [tool_mapping.md](references/tool_mapping.md) 注入正确的数据库、知识库和血缘工具。
- **Manager 配置**：确保新 Agent 被正确列入 `agents` 列表，且由 `pm` (Manager) 进行统一调度。

## 参考资料
- [Agent 编写模式 (Role/Goal/Backstory)](references/agent_patterns.md)
- [Task 编写模式 (CoT/Evidence-based)](references/task_patterns.md)
- [项目工具映射表 (Banking Systems)](references/tool_mapping.md)

## 准则
- **禁止冗余**：不建议在没有明确业务需求的情况下添加通用的 Agent。
- **原子性**：每个 Agent 应该是一个系统的“王牌专家”，功能应当垂直。
- **防御性编程**：所有 Agent 都应预设“SQL 修复”和“无结果汇报”逻辑。
