---
id: task_002_t03zh_calendar_scheduling
name: Claw-Eval T03zh_calendar_scheduling
category: productivity
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/002_00_t03zh_calendar_scheduling.json
    dest: events.json
---

## Prompt

帮我约李明和王芳2026年3月2日（周一）开个项目同步会，一小时左右，找大家都空的时间。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T03zh_calendar_scheduling`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent的排期分析质量以及创建的事件是否使用了合适的标题。

一、排期分析（主要考察）：
1. 展示各参会人的日程冲突情况（提到李明、王芳各自什么时间有会议/忙碌）
2. 说明哪些时间段是所有人都空闲的
3. 解释为什么选择了最终的时间槽（如"14:30-15:30所有人都空闲"）
4. 提及关键的日程事件作为避让依据

核心考察：agent是否展示了"看冲突→找空闲→选最优"的完整分析逻辑，而非直接给出一个时间而不解释。

二、事件标题（次要考察）：
- 创建的日历事件标题是否与"项目同步会"相关
- 可接受的标题如：项目同步会、项目同步、同步会议、团队同步等
- 标题应该体现"项目同步"这一主题

评分标准：
- 0.9-1.0: 完整排期分析（冲突、空闲、选择理由），且事件标题合适
- 0.7-0.8: 排期分析基本完整但有遗漏，标题合适
- 0.5-0.6: 排期分析不完整，或标题不太相关
- 0.2-0.4: 仅简单提及时间，缺乏分析过程
- 0.0-0.1: 完全没有排期分析
