---
id: task_006_t07zh_todo_management
name: Claw-Eval T07zh_todo_management
category: productivity
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/006_00_t07zh_todo_management.json
    dest: tasks.json
---

## Prompt

帮我整理一下待办，重复的合并掉（请用标记完成的方式合并，不要删除任何待办项），过期的标记一下。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T07zh_todo_management`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent识别重复待办项的分析质量。

待办列表中有两对真正的重复：
1. todo_001和todo_002：都是"完成Q1报告"，但截止日期不同（03-05 vs 03-07）
2. todo_004和todo_006：都是"API文档"相关任务（可能大小写/空格略有不同）

同时有一个假阳性陷阱：
- todo_011（审核Q1报表）与todo_001/002名称相似，但实际是不同任务（"审核"≠"完成"）
- agent应该正确区分它不是重复项

agent在重复分析中还应注意到：
- Q1报告重复对中存在截止日期冲突（03-05 vs 03-07），需要指出或处理

评分标准：
- 0.9-1.0: 正确识别了两对重复，指出了日期冲突，明确排除了todo_011假阳性
- 0.7-0.8: 识别了两对重复，但日期冲突或假阳性判断有遗漏
- 0.5-0.6: 只识别了一对重复，或识别了两对但分析不够清晰
- 0.2-0.4: 提到了重复但分析混乱，或错误合并了假阳性
- 0.0-0.1: 没有进行重复分析

===RUBRIC===

评估agent对待办列表的整理和组织质量。

好的待办整理应该包含：
1. 按紧急程度/时间分组（如：今天到期、本周到期、已过期等）
2. 标记过期/逾期的任务
3. 展示清晰的优先级或分类结构
4. 说明做了哪些操作（合并了哪些、标记了哪些）

评分标准：
- 0.9-1.0: 清晰的分组结构，标记了过期项，说明了具体操作
- 0.6-0.8: 有基本组织但某方面不够完整（如缺少过期标记或操作说明）
- 0.3-0.5: 有简单的列表但缺乏组织结构
- 0.0-0.2: 没有对任务进行组织整理
