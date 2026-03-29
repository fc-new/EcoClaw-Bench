---
id: task_092_t93_pinbench_email_triage_report
name: Claw-Eval T93_pinbench_email_triage_report
category: organization
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/092_00_t93_pinbench_email_triage_report.json
    dest: inbox.json
---

## Prompt

Help triage an overflowing inbox using the Gmail service. Read the messages and
produce a report sorted by priority. For each relevant email, assign:
- Priority: P0 to P4
- Category
- Recommended action
Include a short top summary highlighting the most urgent items and a suggested plan
for the day.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T93_pinbench_email_triage_report`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
