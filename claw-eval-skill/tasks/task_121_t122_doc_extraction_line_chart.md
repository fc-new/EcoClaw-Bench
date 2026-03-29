---
id: task_121_t122_doc_extraction_line_chart
name: Claw-Eval T122_doc_extraction_line_chart
category: doc_extraction
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

I am a researcher processing paper data. Please download and read this PDF:
https://openaccess.thecvf.com/content/CVPR2025/papers/Fu_Video-MME_The_First-Ever_Comprehensive_Evaluation_Benchmark_of_Multi-modal_LLMs_in_CVPR_2025_paper.pdf

Based on the main experimental results table, please extract the "w/ subs"
(with subtitles) scores of the three video durations (Short, Medium, Long)
and the Overall score for VILA-1.5 and Gemini 1.5 Pro. Save this data into
a file named /workspace/duration_comparison.csv. Then, create a line chart
with markers comparing the performance trend of these two models across the
three video durations. Ensure the y-axis ranges from 0 to 100, include a
legend, use green for VILA-1.5 and purple for Gemini, and save the final
image as /workspace/duration_trend.png.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T122_doc_extraction_line_chart`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth data (w/ subs scores):
                Short   Medium  Long    Overall
VILA-1.5        68.9    57.4    52.0    59.4
Gemini-1.5-Pro  84.5    81.0    77.4    81.3

Evaluate the CSV content for data accuracy:
- 1.0: All data values match the ground truth exactly.
- 0.7-0.9: Minor discrepancies (e.g., rounding differences within ±0.5).
- 0.3-0.6: Some correct values but significant errors in others.
- 0.0-0.2: Mostly incorrect data.

Output a score between 0.0 and 1.0.

===RUBRIC===

Evaluate this line chart for:

1. Chart Specifications (weight ~67%):
   - Must be a LINE chart with markers (not bar chart, scatter, etc.)
   - X-axis has exactly 3 durations: Short, Medium, Long (excluding Overall)
   - Y-axis range is 0 to 100
   - Legend is present identifying both models
   - Color mapping: Green for VILA-1.5, Purple for Gemini 1.5 Pro
   - Data points match GT: VILA-1.5 (69.9, 55.7, 50.4), Gemini (84.5, 81.0, 77.4)

2. Aesthetic Quality (weight ~33%):
   - No overlapping text/fonts
   - Axis labels are present and readable
   - No misaligned elements
   - Clean and professional appearance

Score 0.0-1.0 based on the weighted combination of these criteria.
