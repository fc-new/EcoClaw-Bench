---
id: task_039_t40_onboarding_coordinator
name: Claw-Eval T40_onboarding_coordinator
category: workflow
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/039_00_t40_onboarding_coordinator.json
    dest: contacts.json
  - source: assets/claw_eval/039_01_t40_onboarding_coordinator.json
    dest: inbox.json
  - source: assets/claw_eval/039_02_t40_onboarding_coordinator.json
    dest: events.json
  - source: assets/claw_eval/039_03_t40_onboarding_coordinator.json
    dest: tasks.json
  - source: assets/claw_eval/039_04_t40_onboarding_coordinator.json
    dest: articles.json
  - source: assets/claw_eval/039_05_t40_onboarding_coordinator.json
    dest: products.json
---

## Prompt

Three new employees are starting next Monday (March 9). Please coordinate their onboarding:
1. Read the HR email for each person's requirements
2. Check the knowledge base for onboarding procedures
3. Look up department managers' contact info
4. Check IT equipment inventory
5. Check calendars for training scheduling (avoid conflicts)
6. Send onboarding notifications to each department manager (Note: for departments without a manager, only save as draft — do not send)
7. Create follow-up todo items
8. Give me an onboarding arrangement summary

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T40_onboarding_coordinator`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
