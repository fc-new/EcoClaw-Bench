---
id: task_082_t83_officeqa_mad_excise_tax
name: Claw-Eval T83_officeqa_mad_excise_tax
category: office_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/082_00_t83_officeqa_mad_excise_tax.txt
    dest: treasury_bulletin_2018_12.txt
  - source: assets/claw_eval/082_01_t83_officeqa_mad_excise_tax.pdf
    dest: treasury_bulletin_2018_12.pdf
---

## Prompt

I have a scanned U.S. Treasury Bulletin from December 2018 (file: treasury_bulletin_2018_12.pdf).
Please extract the text using OCR, then answer this question:

What is the Mean Absolute Deviation of nominal monthly net budget receipts of the U.S.
Federal Government from Excise taxes for FY 2018? Round to the thousandths place and
report in millions of dollars.

Please provide a precise numerical answer.
Put your answer between `<FINAL_ANSWER></FINAL_ANSWER>`.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T83_officeqa_mad_excise_tax`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's methodology in computing the Mean Absolute Deviation (MAD) of monthly net budget receipts from excise taxes for FY2018.
The correct answer is 1,400.306 million dollars.
Score each of the three parts separately, then compute a weighted final score (0-1).

=== Part 1: MAD Computation Method (weight 45%) ===
The agent needed to:
- Understand MAD formula: (1/n) × Σ|xi - mean| where n=12 months
- First compute the mean of all 12 monthly values
- Then compute the absolute deviation of each month from the mean
- Average the absolute deviations
- Show computation steps with actual monthly values

Part 1 scoring:
- 0.9-1.0: Correct MAD formula stated, showed mean computation, showed deviations, correct final result
- 0.7-0.8: Correct formula and result but intermediate steps abbreviated
- 0.5-0.6: Used MAD concept correctly but some computational errors
- 0.2-0.4: Attempted deviation calculation but wrong formula (e.g., standard deviation)
- 0.0-0.1: No statistical computation attempted

=== Part 2: Data Extraction (weight 30%) ===
- Extracted all 12 monthly excise tax receipt values for FY2018
- Correctly identified FY2018 as October 2017 through September 2018
- Found the correct table (net budget receipts, excise taxes category)
- Handled OCR data quality issues appropriately

Part 2 scoring:
- 0.9-1.0: All 12 months extracted from correct table with correct FY period
- 0.7-0.8: Most months extracted correctly, minor gaps
- 0.4-0.6: Some monthly data found but incomplete or wrong table
- 0.0-0.3: Failed to extract monthly data

=== Part 3: Answer Presentation (weight 25%) ===
- Reported with correct precision (thousandths place: 1400.306)
- Stated units (millions of dollars)
- Explained what MAD measures in this context

Part 3 scoring:
- 0.9-1.0: Correct precision, correct units, explained MAD meaning
- 0.6-0.8: Correct precision and units but no explanation
- 0.3-0.5: Answer given but wrong precision or missing units
- 0.0-0.2: No clear answer

Output the final weighted score: score = 0.45×Part1 + 0.30×Part2 + 0.25×Part3
