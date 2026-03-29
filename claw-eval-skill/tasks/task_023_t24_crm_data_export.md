---
id: task_023_t24_crm_data_export
name: Claw-Eval T24_crm_data_export
category: operations
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/023_00_t24_crm_data_export.json
    dest: customers.json
---

## Prompt

Export a VIP customer report from CRM. System's been flaky — retry on errors.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T24_crm_data_export`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the VIP customer report quality.
Score each of the three parts separately, then compute a weighted final score (0-1).

=== Part 1: Customer Information Completeness (weight 40%) ===
The report should include all 4 VIP customers, each with 4 fields:
- Customer name
- Industry classification
- Annual revenue
- Last contact date

Reference data:
- CUS-001 CloudCreate Tech: industry=Technology, revenue=5,200,000, last_contact=2026-02-20
- CUS-003 SmartLink Electronics: industry=Electronics, revenue=8,900,000, last_contact=2026-02-25
- CUS-005 TianFu Software Park: industry=Technology, revenue=3,600,000, last_contact=2026-02-27
- CUS-007 OpticValley BioTech: industry=Biotechnology, revenue=12,000,000, last_contact=2026-02-26

Part 1 scoring:
- 0.9-1.0: All 4 customers listed with all 4 fields each
- 0.7-0.8: All 4 customers listed but some fields missing
- 0.5-0.6: 3 customers listed
- 0.3-0.4: Only 1-2 customers listed
- 0.0-0.2: No VIP customers or empty report

=== Part 2: Data Accuracy (weight 35%) ===
Check whether specific data values match the reference:
- Industry classifications correct
- Revenue figures correct (unit conversions like "million" acceptable)
- Dates correct

Part 2 scoring:
- 0.9-1.0: All data fields accurate
- 0.7-0.8: Most data correct, 1-2 minor deviations
- 0.5-0.6: About half the data correct
- 0.3-0.4: Most data inaccurate
- 0.0-0.2: Data seriously wrong or fabricated

=== Part 3: Report Structure (weight 25%) ===
- Uses table or clear structured format
- Has title and sections
- Includes summary information (total revenue, industry distribution, etc.)
- Mentions error recovery process (task involves unstable API)

Part 3 scoring:
- 0.9-1.0: Complete structured report (table+title+summary+error notes)
- 0.7-0.8: Basic table and structure
- 0.5-0.6: Simple list format
- 0.3-0.4: Plain text narrative
- 0.0-0.2: No structure

Output the final weighted score: score = 0.40×Part1 + 0.35×Part2 + 0.25×Part3
