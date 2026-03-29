---
id: task_095_t96_pinbench_business_metrics_summary
name: Claw-Eval T96_pinbench_business_metrics_summary
category: data_analysis
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/095_00_t96_pinbench_business_metrics_summary.csv
    dest: quarterly_sales.csv
  - source: assets/claw_eval/095_01_t96_pinbench_business_metrics_summary.xlsx
    dest: company_expenses.xlsx
  - source: assets/claw_eval/095_02_t96_pinbench_business_metrics_summary.txt
    dest: company_expenses_extracted.txt
---

## Prompt

Analyze the two attached business data files and prepare a concise business
metrics summary.

The sales file is a CSV. The expense file is a text extraction of the original
multi-sheet `company_expenses.xlsx` workbook.

Include:
- Total revenue, total profit, total units sold, the top-performing region by
  revenue, and the top-selling product by revenue from the sales data
- Total Q1 expenses, the department with the highest expenses, the employee with
  the highest total expenses, and a Q1 budget-vs-actual comparison by department
- A short overall insights section that combines both files

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T96_pinbench_business_metrics_summary`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
