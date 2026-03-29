---
id: task_059_t60_finance_tko_endeavor_cost
name: Claw-Eval T60_finance_tko_endeavor_cost
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

What was the total consideration cost TKO paid to acquire Endeavor assets?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T60_finance_tko_endeavor_cost`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent found the correct figure.

The correct answer is approximately $3.25 billion in total consideration paid by TKO Group Holdings to acquire Endeavor assets.
Key facts the response should contain:
- Company: TKO Group Holdings (TKO)
- Deal: acquisition of Endeavor assets
- Metric: total consideration (acquisition cost)
- Amount: approximately $3.25 billion

Scoring guidance:
- 0.90-1.00: Correctly states $3.25 billion with deal context (TKO, Endeavor)
- 0.70-0.89: Correct amount with minor context gaps
- 0.40-0.69: Partially correct or vague on amount
- 0.00-0.39: Wrong amount or no meaningful answer
