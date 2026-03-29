---
id: task_097_t98_pinbench_openclaw_facts
name: Claw-Eval T98_pinbench_openclaw_facts
category: comprehension
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/097_00_t98_pinbench_openclaw_facts.pdf
    dest: OpenClaw Agent Use Cases and Gap Analysis for PinchBench.pdf
---

## Prompt

Use the PDF parsing tool to read
`fixtures/docs/OpenClaw Agent Use Cases and Gap Analysis for PinchBench.pdf`
and answer the eight questions in order, one per line.

Questions:
1. Total skills before filtering
2. Remaining skills after filtering
3. Largest category and count
4. Second-largest category and count
5. Skill definition file
6. Gateway API type
7. Data collection date
8. Number of proposed benchmark tasks

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T98_pinbench_openclaw_facts`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
