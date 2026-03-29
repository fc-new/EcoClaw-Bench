---
id: task_038_t39zh_onboarding_coordinator
name: Claw-Eval T39zh_onboarding_coordinator
category: workflow
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/038_00_t39zh_onboarding_coordinator.json
    dest: contacts.json
  - source: assets/claw_eval/038_01_t39zh_onboarding_coordinator.json
    dest: inbox.json
  - source: assets/claw_eval/038_02_t39zh_onboarding_coordinator.json
    dest: events.json
  - source: assets/claw_eval/038_03_t39zh_onboarding_coordinator.json
    dest: tasks.json
  - source: assets/claw_eval/038_04_t39zh_onboarding_coordinator.json
    dest: articles.json
  - source: assets/claw_eval/038_05_t39zh_onboarding_coordinator.json
    dest: products.json
---

## Prompt

下周一（3月9日）有3位新员工入职。请帮我协调安排入职事宜：
1. 查看HR发来的入职邮件了解各人需求
2. 查看知识库了解入职流程
3. 查找各部门经理的联系方式
4. 检查IT设备库存
5. 查看日历安排培训时间（注意避免冲突）
6. 给各部门经理发送入职通知（注意：对于没有部门经理的部门，只保存草稿不发送）
7. 创建入职跟进待办事项
8. 给我一份入职安排总结

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T39zh_onboarding_coordinator`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
