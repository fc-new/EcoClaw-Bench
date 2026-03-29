---
id: task_060_t61_finance_mu_gm_beat
name: Claw-Eval T61_finance_mu_gm_beat
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

How many basis points did Micron Technology (MU) beat or miss Q3 2024 GAAP gross margin guidance?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T61_finance_mu_gm_beat`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent found the correct answer.

The correct answer is that Micron Technology (MU) beat Q3 2024 GAAP gross margin guidance by 140 basis points.
Key facts the response should contain:
- Company: Micron Technology (MU)
- Period: Q3 2024 (fiscal quarter)
- Metric: GAAP gross margin vs. guidance
- Direction: beat (outperformed)
- Amount: 140 basis points (bps)

Scoring guidance:
- 0.90-1.00: Correctly states 140 bps beat with direction and context (GAAP, Q3 2024)
- 0.70-0.89: Correct value and direction with minor context gaps
- 0.40-0.69: Partially correct (wrong bps or missing beat/miss direction)
- 0.00-0.39: Wrong answer or no meaningful response
