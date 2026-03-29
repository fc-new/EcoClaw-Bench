---
id: task_053_t54_finance_nflx_arppu_trend
name: Claw-Eval T54_finance_nflx_arppu_trend
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

How has Netflix's (NASDAQ: NFLX) Average Revenue Per Paying User Changed from 2019 to 2024?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T54_finance_nflx_arppu_trend`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent correctly reported Netflix's ARPPU trend from 2019 to 2024.

The correct answer includes year-by-year values and trend interpretation:
Key facts the response should contain:
- Company: Netflix (NFLX)
- Metric: Average Revenue Per Paying User (ARPPU), in USD
- Year-by-year values: 2019: $10.82, 2020: $10.91, 2021: $11.67, 2022: $11.76, 2023: $11.64, 2024: $11.70
- Trend 2019-2022: increased at roughly 2.8% annually
- Trend 2022-2024: broadly flat, likely due to lower-priced ad plans

Scoring guidance:
- 0.90-1.00: All yearly values + trend interpretation present and accurate.
- 0.70-0.89: Mostly accurate with minor omission/phrasing issues.
- 0.40-0.69: Some correct values but key anchors missing.
- 0.00-0.39: Major factual errors or no meaningful trend answer.
