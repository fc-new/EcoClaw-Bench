---
id: task_061_t62_finance_pltr_cagr
name: Claw-Eval T62_finance_pltr_cagr
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Calculate the 2-year revenue CAGR for Palantir Technologies (PLTR) from 2022 to 2024.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T62_finance_pltr_cagr`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the calculation methodology is correct and the answer is accurate.

The correct answer is approximately 22.6% for Palantir Technologies (PLTR) 2-year revenue CAGR from 2022 to 2024.
Key facts the response should contain:
- Company: Palantir Technologies (PLTR)
- Period: 2022 to 2024 (2-year CAGR)
- 2022 revenue: approximately $1,905 million
- 2024 revenue: approximately $2,865 million
- CAGR formula: (End/Start)^(1/n) - 1
- Result: approximately 22.6%

The agent should:
1) Find Palantir 2022 revenue from real financial data
2) Find Palantir 2024 revenue from real financial data
3) Apply CAGR formula: (End/Start)^(1/n) - 1 where n=2
4) Report the result as a percentage

Scoring guidance:
- 0.90-1.00: Answer is approximately 22.6% with all steps and key facts present
- 0.70-0.89: Answer is in range 20%-25% with correct methodology
- 0.40-0.69: Correct methodology but answer is materially off, or missing steps
- 0.00-0.39: Wrong methodology or no meaningful calculation
