---
id: task_098_t99_pinbench_second_brain_recall
name: Claw-Eval T99_pinbench_second_brain_recall
category: memory
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/098_00_t99_pinbench_second_brain_recall.json
    dest: memory.json
---

## Prompt

Treat the notes service as a persisted second brain. Find the stored memory note
and answer these questions:
1. What is my favorite programming language?
2. When did I start learning it?
3. What is my mentor's name and affiliation?
4. What is my project called and what does it do?
5. What is my team's secret code phrase?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T99_pinbench_second_brain_recall`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
