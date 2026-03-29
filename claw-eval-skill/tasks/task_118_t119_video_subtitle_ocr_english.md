---
id: task_118_t119_video_subtitle_ocr_english
name: Claw-Eval T119_video_subtitle_ocr_english
category: video_ocr
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/118_00_t119_video_subtitle_ocr_english.webm
    dest: video.webm
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.webm

I'm a video editor. Please help me extract all flashing English words
between 0:25 and 0:30 in the video. Output all the English words in the
order they appear, and do not output duplicate words caused by text
lingering on the screen. Output only the clean and complete string in the
final answer.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T119_video_subtitle_ocr_english`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth: "Two sizes. Two new blacks. Black black. And really black. Jet black. Black so black it's black to the core."

Note: Ignore punctuation and case.
- 1.0: All words appear exactly (no missing or extra words), and in the correct order.
- 0.8: 2 or fewer word errors (including missing, extra, or incorrect words).
- 0.5: 5 or fewer word errors.
- 0.0: More than 5 word errors.

Evaluate the agent's final answer against the ground truth using the criteria above.
Output a score between 0.0 and 1.0.
