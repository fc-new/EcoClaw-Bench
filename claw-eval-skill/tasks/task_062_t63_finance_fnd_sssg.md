---
id: task_062_t63_finance_fnd_sssg
name: Claw-Eval T63_finance_fnd_sssg
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

What was Floor & Decor Holdings (FND) same-store sales growth in Q4 2024?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T63_finance_fnd_sssg`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent found the correct figure.

The correct answer is -0.8% same-store sales growth for Floor & Decor (FND) in Q4 2024.
Key facts the response should contain:
- Company: Floor & Decor Holdings (FND)
- Period: Q4 2024
- Metric: same-store sales growth (comparable store sales)
- Value: -0.8%

Scoring guidance:
- 0.90-1.00: Correctly states -0.8% with all key facts present
- 0.70-0.89: Correct value with minor context gaps
- 0.40-0.69: Close but materially off on value
- 0.00-0.39: Wrong value or no meaningful answer
