---
id: task_123_t124_multi_doc_extraction_bar_chart
name: Claw-Eval T124_multi_doc_extraction_bar_chart
category: doc_extraction
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

I am writing a meta-analysis survey on visual grounding. Please download
the following three PDF papers and save them to /workspace/papers/:
- https://arxiv.org/pdf/2511.21631
- https://arxiv.org/pdf/2507.01006
- https://arxiv.org/pdf/2505.07062

Scan all the PDF files in the /workspace/papers/ directory. Extract the
overall accuracy scores for three specific models: Qwen3-VL-A22B-Instruct,
GLM-4.6V, and Seed-1.5-VL-Thinking, across two different benchmarks:
RefCOCO-avg (val) and ERQA. Save the synthesized data into a file named
/workspace/meta_analysis.csv with exactly three columns: Model, RefCOCO-avg,
and ERQA. Then, create a Grouped Bar Chart comparing these three models
side-by-side on the two benchmarks. Save the final image as
/workspace/cross_benchmark_comparison.png.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T124_multi_doc_extraction_bar_chart`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth data:
Model                       RefCOCO-avg     ERQA
Qwen3-VL-A22B-Instruct     91.9            51.3
GLM-4.6V                   88.6            47.8
Seed-1.5-VL-Thinking       91.3            NaN

Evaluate the CSV content for:
1. Data accuracy: All numerical values match the ground truth.
2. Anomaly handling: The agent correctly identifies that the ERQA score for
   Seed-1.5-VL-Thinking is missing/unavailable and represents it as NaN or
   empty (not as 0 or a guessed value).

Scoring:
- 1.0: All values correct AND missing ERQA properly handled as NaN/empty.
- 0.7-0.9: Values correct but NaN handling imperfect (e.g., marked as 0).
- 0.3-0.6: Some correct values but significant errors.
- 0.0-0.2: Mostly incorrect data.

Output a score between 0.0 and 1.0.

===RUBRIC===

Evaluate this grouped bar chart for:

1. Chart Specifications (weight ~67%):
   - Must be a GROUPED Bar Chart (bars side-by-side, NOT stacked)
   - Legend is present identifying the two benchmarks (RefCOCO-avg and ERQA)
   - X-axis labels show the three model names correctly
   - The missing Seed-1.5-VL-Thinking ERQA data is handled gracefully
     (no crash, no misleading bar at 0)
   - Data values visually match the GT

2. Aesthetic Quality (weight ~33%):
   - Text elements (model names on x-axis) are fully visible, not cropped/overlapping
   - Axis labels are present and readable
   - Clean and professional appearance

Score 0.0-1.0 based on the weighted combination of these criteria.
