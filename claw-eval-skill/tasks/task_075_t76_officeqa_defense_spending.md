---
id: task_075_t76_officeqa_defense_spending
name: Claw-Eval T76_officeqa_defense_spending
category: office_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/075_00_t76_officeqa_defense_spending.txt
    dest: treasury_bulletin_1941_01.txt
  - source: assets/claw_eval/075_01_t76_officeqa_defense_spending.pdf
    dest: treasury_bulletin_1941_01.pdf
---

## Prompt

I have a scanned U.S. Treasury Bulletin from January 1941 (file: treasury_bulletin_1941_01.pdf).
Please extract the text using OCR, then answer this question:

What were the total expenditures (in millions of nominal dollars) for U.S national defense
in the calendar year of 1940?

Please provide a precise numerical answer.
Put your answer between `<FINAL_ANSWER></FINAL_ANSWER>`.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T76_officeqa_defense_spending`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the quality of the agent's answer explanation for finding U.S. national defense expenditures in 1940 from a Treasury Bulletin.
Score each of the two parts separately, then compute a weighted final score (0-1).

=== Part 1: Data Source & Extraction Process (weight 50%) ===
The agent should demonstrate it correctly processed the OCR output:
- Referenced the Treasury Bulletin as the data source
- Identified the correct table/section containing defense expenditures
- Showed how it located the 1940 calendar year data
- Distinguished between fiscal year and calendar year if relevant

Part 1 scoring:
- 0.9-1.0: Clearly described data source and extraction process, referenced specific table/section
- 0.6-0.8: Mentioned data source but extraction process unclear
- 0.3-0.5: Gave an answer without explaining how it was found
- 0.0-0.2: No reference to data source or extraction method

=== Part 2: Answer Presentation & Context (weight 50%) ===
The agent should present the answer clearly with appropriate context:
- Stated the answer with correct units (millions of dollars)
- Provided context (e.g., "national defense" category, calendar year 1940)
- Noted any caveats or data quality issues from OCR

Part 2 scoring:
- 0.9-1.0: Clear answer with units, context, and any relevant caveats
- 0.6-0.8: Answer with units but minimal context
- 0.3-0.5: Just a number without units or context
- 0.0-0.2: No clear answer presented

Output the final weighted score: score = 0.50×Part1 + 0.50×Part2
