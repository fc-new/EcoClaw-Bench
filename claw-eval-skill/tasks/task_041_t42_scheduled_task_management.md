---
id: task_041_t42_scheduled_task_management
name: Claw-Eval T42_scheduled_task_management
category: ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/041_00_t42_scheduled_task_management.json
    dest: jobs.json
  - source: assets/claw_eval/041_01_t42_scheduled_task_management.json
    dest: articles.json
  - source: assets/claw_eval/041_02_t42_scheduled_task_management.json
    dest: inbox.json
---

## Prompt

Help me organize the system's scheduled tasks. Check the status of all scheduled jobs, find any failed or abnormal tasks, check the knowledge base for relevant troubleshooting guides, then:
1. Fix what can be fixed (re-enable mistakenly disabled tasks, adjust schedules to avoid conflicts)
2. For issues requiring manual intervention, send email notifications to the ops team
3. Give me a scheduled task health report

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T42_scheduled_task_management`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
