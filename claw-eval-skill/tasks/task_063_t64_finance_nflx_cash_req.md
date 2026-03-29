---
id: task_063_t64_finance_nflx_cash_req
name: Claw-Eval T64_finance_nflx_cash_req
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

What are Netflix's Total Projected Material Cash Requirements for 2025?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T64_finance_nflx_cash_req`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent found the correct figure.

The correct answer is $14,426,266,000 (approximately $14.4 billion).
Key facts the response should contain:
- Company: Netflix (NFLX)
- Year: 2025
- Metric: total projected material cash requirements
- Amount: $14,426,266,000 or approximately $14.4 billion

Scoring guidance:
- 0.90-1.00: Correctly states $14,426,266,000 or $14.4 billion with all key facts
- 0.70-0.89: Close figure with minor formatting differences
- 0.40-0.69: Approximate range but not precise
- 0.00-0.39: Wrong figure or no meaningful answer
