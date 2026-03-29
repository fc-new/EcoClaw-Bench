---
id: task_065_t66_finance_bros_gross_profit
name: Claw-Eval T66_finance_bros_gross_profit
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Assume Dutch Bros (BROS) grows revenue by 30% CAGR and gross margins compress by 500 basis points from year-end 2024 levels. What is BROS gross profit in 2026?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T66_finance_bros_gross_profit`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the calculation methodology is correct and the answer is accurate.

The correct answer is approximately $467 million for Dutch Bros (BROS) 2026 gross profit.
Key facts the response should contain:
- Company: Dutch Bros (BROS)
- Projection year: 2026
- Metric: gross profit
- Revenue growth assumption: 30% CAGR for 2 years
- Gross margin compression assumption: 500 basis points from 2024 levels
- 2026 revenue: approximately $2,165M
- 2026 gross margin: approximately 21.5%
- 2026 gross profit: approximately $467M

The agent should:
1) Find Dutch Bros 2024 revenue and gross margin from real financial data
2) Apply 30% CAGR for 2 years to get 2026 revenue
3) Subtract 500 basis points from 2024 gross margin to get 2026 gross margin
4) Multiply 2026 revenue by 2026 gross margin to get gross profit

Scoring guidance:
- 0.90-1.00: Answer is approximately $467M with all four steps and key facts present
- 0.70-0.89: Answer is in range $420M-$520M with correct methodology
- 0.40-0.69: Correct methodology but answer is materially off, or missing key steps
- 0.00-0.39: Wrong methodology or no meaningful calculation
