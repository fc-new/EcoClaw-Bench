---
id: task_085_t86_pinbench_calendar_event_creation
name: Claw-Eval T86_pinbench_calendar_event_creation
category: productivity
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/085_00_t86_pinbench_calendar_event_creation.json
    dest: events.json
---

## Prompt

You do not have access to a real calendar file system. Use the calendar service to
create a meeting on 2026-03-10 at 3:00 PM local time with john@example.com.
Title it "Project Sync" and include a note in your confirmation that the meeting is
for discussing the Q1 roadmap.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T86_pinbench_calendar_event_creation`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
