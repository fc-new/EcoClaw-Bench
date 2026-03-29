---
id: task_064_t65_finance_x_inv_turnover
name: Claw-Eval T65_finance_x_inv_turnover
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Calculate the inventory turnover ratio for United States Steel Corporation (X) in FY2024.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T65_finance_x_inv_turnover`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the calculation methodology is correct and the answer is accurate.

The correct answer is approximately 6.55 for United States Steel Corporation (ticker: X) FY2024 inventory turnover.
Key facts the response should contain:
- Company: United States Steel Corporation (X)
- Period: FY2024
- COGS: approximately $14,060 million
- Beginning inventory: approximately $2,168 million
- Ending inventory: approximately $2,128 million
- Average inventory: approximately $2,148 million
- Inventory turnover ratio: approximately 6.55

The agent should:
1) Find US Steel FY2024 COGS from real financial data
2) Find beginning and ending inventory figures
3) Calculate average inventory = (beginning + ending) / 2
4) Calculate inventory turnover = COGS / average inventory

Scoring guidance:
- 0.90-1.00: Answer is approximately 6.55 with all four steps and key facts present
- 0.70-0.89: Answer is close (6.3-6.8) with correct methodology
- 0.40-0.69: Correct methodology but answer is materially off, or missing steps
- 0.00-0.39: Wrong methodology or no meaningful calculation
