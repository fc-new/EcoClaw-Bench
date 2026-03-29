---
id: task_077_t78_officeqa_max_yield_spread
name: Claw-Eval T78_officeqa_max_yield_spread
category: office_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/077_00_t78_officeqa_max_yield_spread.txt
    dest: treasury_bulletin_1970_06.txt
  - source: assets/claw_eval/077_01_t78_officeqa_max_yield_spread.pdf
    dest: treasury_bulletin_1970_06.pdf
---

## Prompt

I have a scanned U.S. Treasury Bulletin from June 1970 (file: treasury_bulletin_1970_06.pdf).
Please extract the text using OCR, then answer this question:

Between the calendar years 1960 to 1969 (inclusive), find the month and year in which the
yield spread between US corporate Aa bonds and US Treasury bonds was maximized. Represent
the corresponding month and year as a six-digit integer MMYYYY (e.g., March 1965 = 031965).

Please provide a precise numerical answer.
Put your answer between `<FINAL_ANSWER></FINAL_ANSWER>`.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T78_officeqa_max_yield_spread`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's analytical reasoning in finding the month with maximum yield spread between US corporate Aa bonds and US Treasury bonds during 1960-1969.
The correct answer is 031969 (March 1969 in MMYYYY format).
Score each of the three parts separately, then compute a weighted final score (0-1).

=== Part 1: Yield Spread Computation & Comparison (weight 45%) ===
The agent needed to:
- Identify or compute yield spreads for each month across 1960-1969
- Compare spreads across the full 10-year period to find the maximum
- Show its work: which months/years had high spreads, how it determined the max

Part 1 scoring:
- 0.9-1.0: Showed spread values for multiple months/years, clearly demonstrated March 1969 had the maximum with supporting data
- 0.7-0.8: Identified March 1969 as max with some supporting data but incomplete comparison
- 0.5-0.6: Found a high-spread period (late 1960s) but didn't precisely identify March 1969
- 0.2-0.4: Attempted spread calculation but major errors or incomplete
- 0.0-0.1: No spread computation or comparison attempted

=== Part 2: Data Source & Table Identification (weight 25%) ===
- Referenced the Treasury Bulletin (June 1970) as source
- Identified the correct table with corporate Aa bond yields AND Treasury bond yields
- Correctly understood that spread = corporate yield - Treasury yield (or similar)

Part 2 scoring:
- 0.9-1.0: Clear source reference, correct table identified, spread definition understood
- 0.6-0.8: Source mentioned, table roughly identified
- 0.3-0.5: Gave answer without clear table reference
- 0.0-0.2: No source or table identification

=== Part 3: Answer Format & Presentation (weight 30%) ===
- Correctly formatted answer as MMYYYY integer (031969 for March 1969)
- Explained what the number represents (month=03, year=1969)
- Stated the actual spread value at that peak month

Part 3 scoring:
- 0.9-1.0: Correct MMYYYY format, explained the encoding, stated the peak spread value
- 0.6-0.8: Correct format but didn't explain encoding or omitted spread value
- 0.3-0.5: Identified March 1969 but wrong format (e.g., "March 1969" instead of 031969)
- 0.0-0.2: No clear answer or completely wrong format

Output the final weighted score: score = 0.45×Part1 + 0.25×Part2 + 0.30×Part3
