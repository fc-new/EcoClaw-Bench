---
id: task_122_t123_doc_extraction_radar_chart
name: Claw-Eval T123_doc_extraction_radar_chart
category: doc_extraction
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/122_00_t123_doc_extraction_radar_chart.pdf
    dest: GroundingME.pdf
---

## Prompt

The container has the following file:
- /workspace/fixtures/GroundingME.pdf

I am a researcher processing paper data. Based on the main experimental
results table, please extract the average scores of the four L-1 dimensions
and the Total score for Qwen3-VL-A22B and Gemini-2.5-Pro. Save this data
into a file named /workspace/model_comparison.csv. Then, create a radar chart
comparing these two models on the four L-1 dimensions. Ensure the chart axes
range from 0 to 100, include a legend, use blue for Qwen3 and red for Gemini,
and save the final image as /workspace/comparison_radar.png.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T123_doc_extraction_radar_chart`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth data (4 L-1 dimensions + Total):
                Dim1    Dim2    Dim3    Dim4    Total
Qwen3-VL-A22B  69.6    49.7    54.0    0.0     45.1
Gemini-2.5-Pro  34.8    34.0    7.0     7.0     20.7

Evaluate the CSV content for data accuracy:
- 1.0: All data values match the ground truth exactly.
- 0.7-0.9: Minor discrepancies (e.g., rounding differences within ±0.5).
- 0.3-0.6: Some correct values but significant errors in others.
- 0.0-0.2: Mostly incorrect data.

Output a score between 0.0 and 1.0.

===RUBRIC===

Evaluate this radar chart for:

1. Chart Specifications (weight ~67%):
   - Must be a RADAR chart (spider/web chart)
   - Includes exactly 4 L-1 dimensions (excluding Total)
   - Axis range is 0 to 100
   - Legend is present identifying both models
   - Color mapping: Blue for Qwen3, Red for Gemini
   - Data points should match GT values on the 4 dimensions

2. Aesthetic Quality (weight ~33%):
   - No overlapping text/fonts
   - Labels are readable on all axes
   - No incomplete layers or misaligned elements
   - Clean and professional appearance

Score 0.0-1.0 based on the weighted combination of these criteria.
