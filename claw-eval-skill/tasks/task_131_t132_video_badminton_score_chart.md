---
id: task_131_t132_video_badminton_score_chart
name: Claw-Eval T132_video_badminton_score_chart
category: video_chart
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/131_00_t132_video_badminton_score_chart.mp4
    dest: video.mp4
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.mp4

Please track every point scored by both players in the video and create a line chart showing the score progression. The x-axis should represent the match time, and the y-axis should represent the cumulative score. Use different colored lines for each player, and annotate each point of score change with the exact score at that moment (e.g., 5:3, 8:11) to create a comprehensive match analysis chart. On the x-axis, you only need to label four specific timestamps: 7:56, 12:46, 21:26, and 25:03, and please bold the corresponding scores at these exact times. Save the chart as /workspace/score_chart.png.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T132_video_badminton_score_chart`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate this badminton match score chart for structural correctness:

1. Chart Type (0.2): Is it a LINE chart (not bar/scatter/etc.)?
2. Axis Semantics (0.2): X-axis = match time, Y-axis = cumulative score?
3. Dual-Line Distinctiveness (0.2): At least 2 line graphs with clearly different colors?
4. Player Names (0.4): Legend or labels contain both "Kento MOMOTA" and "Viktor AXELSEN" (case differences allowed, spelling must be fundamentally correct)?

Score 0.0-1.0 based on these criteria.

===RUBRIC===

Evaluate this badminton match score chart for data accuracy:

Ground truth score sequence (Momota:Axelsen):
0:0, 0:1, 1:1, 2:1, 2:2, 3:2, 4:2, 5:2, 6:2, 6:3, 7:3, 7:4, 8:4, 9:4, 9:5, 9:6, 9:7, 9:8, 10:8, 10:9, 11:9, 12:9, 12:10, 13:10, 13:11, 14:11, 15:11, 16:11, 17:11, 18:11, 19:11, 20:11, 21:11

Key timestamps with scores (must be bold):
7:56 (1:1), 12:46 (7:3), 21:26 (11:9), 25:03 (13:11)

Evaluation criteria:
1. Score annotations (0.5): Are score change points annotated on the chart? Compare annotated sequence against ground truth. Score based on edit-distance similarity (ratio >= 0.6 maps linearly, <0.6 = 0).
2. Timestamp labels (0.15): Are timestamps 7:56, 12:46, 21:26, 25:03 marked on x-axis?
3. Key score accuracy (0.35): At those 4 timestamps, are the scores displayed and correct? Are they bolded?

Score 0.0-1.0 based on weighted criteria.
