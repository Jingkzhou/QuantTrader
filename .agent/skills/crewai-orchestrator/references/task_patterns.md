# Task 编写模式 (CoT/Evidence-based)

Task 是驱动 Agent 执行的指令，必须清晰、分步且强调事实。

## 1. PM 统一任务模板 (Plan-and-Solve)

```python
def create_unified_task(user_input: str) -> Task:
    return Task(
        description=f"""你必须执行以下 Chain of Thought (CoT) 步骤：
1. 【Think】识别主系统与排查优先级。
2. 【Plan】制定精准、分步的执行计划。
3. 【Delegate】精准指派对应的负责人，严禁冗余调用。
4. 【Synthesize】汇总结果并执行严苛的事实核查。
   - **Grounding**: 每一个结论必须建立在返回的证据之上。
   - **禁止猜测**: 查不到不代表没问题，请诚实报告。""",
        expected_output="包含思考过程的执行报告和对用户的总结回复",
    )
```

## 2. 专家排查任务模板

```python
def create_xxx_task(agent, user_input: str) -> Task:
    return Task(
        description=f"针对用户问题 '{user_input}'，请利用你的工具集进行闭环排查：查询规则、调取数据、分析血缘，并给出事实依据。",
        expected_output="包含数据库记录、知识库原文和血缘分析路径的详细技术方案",
        agent=agent
    )
```
