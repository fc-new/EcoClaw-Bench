---
id: task_040_t41zh_scheduled_task_management
name: Claw-Eval T41zh_scheduled_task_management
category: ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/040_00_t41zh_scheduled_task_management.json
    dest: jobs.json
  - source: assets/claw_eval/040_01_t41zh_scheduled_task_management.json
    dest: articles.json
  - source: assets/claw_eval/040_02_t41zh_scheduled_task_management.json
    dest: inbox.json
---

## Prompt

帮我整理一下系统的定时任务。检查所有计划任务的运行状态，找出失败或异常的任务，查看知识库里有没有相关的排查指南，然后：
1. 修复能修复的（重新启用被误禁用的任务、调整时间避免冲突）
2. 对于需要人工介入的问题，发邮件通知运维团队
3. 给我一份定时任务健康报告

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T41zh_scheduled_task_management`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
