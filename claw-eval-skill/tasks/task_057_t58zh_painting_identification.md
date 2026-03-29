---
id: task_057_t58zh_painting_identification
name: Claw-Eval T58zh_painting_identification
category: OCR
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/057_00_t58zh_painting_identification.jpg
    dest: image.jpg
---

## Prompt

这件字画是啥？图片路径是 fixtures/media/image.jpg

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T58zh_painting_identification`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
