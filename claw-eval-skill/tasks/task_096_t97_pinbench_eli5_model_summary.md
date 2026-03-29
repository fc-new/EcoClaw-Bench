---
id: task_096_t97_pinbench_eli5_model_summary
name: Claw-Eval T97_pinbench_eli5_model_summary
category: comprehension
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/096_00_t97_pinbench_eli5_model_summary.pdf
    dest: GPT4.pdf
---

## Prompt

Use the PDF parsing tool to read `fixtures/docs/GPT4.pdf`, then explain it like the
reader is five years old. Use simple words, short sentences, and everyday analogies.
Aim for about 200-400 words.

Make sure you explain:
- what GPT-4 is
- what kinds of things it seems good at
- why the researchers think it is important
- that it still has limits and can make mistakes

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T97_pinbench_eli5_model_summary`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
