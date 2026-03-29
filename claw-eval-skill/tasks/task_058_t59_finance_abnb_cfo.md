---
id: task_058_t59_finance_abnb_cfo
name: Claw-Eval T59_finance_abnb_cfo
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Who is the CFO of Airbnb as of April 07, 2025?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T59_finance_abnb_cfo`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent found the correct answer.

The correct answer is that Elinor Mertz is the CFO of Airbnb as of April 2025.
Key facts the response should contain:
- Company: Airbnb (ABNB)
- Title: CFO / Chief Financial Officer
- Name: Elinor Mertz
- As of: April 2025

Scoring guidance:
- 0.90-1.00: Correctly identifies Elinor Mertz as CFO with clear context.
- 0.70-0.89: Correct name with minor omissions.
- 0.40-0.69: Partially correct or missing key details.
- 0.00-0.39: Wrong name or no meaningful answer.
