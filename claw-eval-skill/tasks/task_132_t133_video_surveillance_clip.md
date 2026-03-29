---
id: task_132_t133_video_surveillance_clip
name: Claw-Eval T133_video_surveillance_clip
category: video_edit
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/132_00_t133_video_surveillance_clip.mp4
    dest: video.mp4
---

## Prompt

容器里有以下文件：
- /workspace/fixtures/video.mp4

识别这段监控录像中的撞车事件出现时间（以视频中呈现的时间为准），并截取相关片段，保存为 /workspace/clip.mp4。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `multimodal`
Original task id: `T133_video_surveillance_clip`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth: The crash event occurs at 2018-10-16 16:40:26 to 16:40:41 (as shown by the timestamp overlay in the surveillance video).

The agent was asked to identify the crash time and extract a clip. Evaluate the agent's identified time range against the ground truth:

Scoring based on temporal IoU (Intersection over Union):
- Calculate the overlap between the agent's extracted time range and GT range.
- IoU = intersection_duration / union_duration.
- Score = IoU (0.0-1.0).

If the agent mentions specific timestamps, use those for comparison.
If the agent's clip covers the crash event with reasonable margins, give proportional credit.
If no timestamps are mentioned or they are completely wrong, score 0.0.

Output a score between 0.0 and 1.0.

===RUBRIC===

Evaluate these frames extracted from a surveillance clip:
- Do the frames show a car crash / collision event? (0.5)
- Is the scene from a traffic surveillance camera perspective? (0.25)
- Are there visible timestamp overlays consistent with surveillance footage? (0.25)

Score 0.0-1.0 based on whether the extracted clip captures the crash event.
