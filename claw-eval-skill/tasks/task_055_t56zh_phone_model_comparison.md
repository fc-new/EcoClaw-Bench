---
id: task_055_t56zh_phone_model_comparison
name: Claw-Eval T56zh_phone_model_comparison
category: OCR
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/055_00_t56zh_phone_model_comparison.jpg
    dest: image.jpg
---

## Prompt

这是什么手机？图片路径是 fixtures/media/image.jpg

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T56zh_phone_model_comparison`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
