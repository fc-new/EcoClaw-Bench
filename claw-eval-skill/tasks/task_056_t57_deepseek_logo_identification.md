---
id: task_056_t57_deepseek_logo_identification
name: Claw-Eval T57_deepseek_logo_identification
category: OCR
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/056_00_t57_deepseek_logo_identification.jpg
    dest: image.jpg
---

## Prompt

Which company does this logo belong to? The image is at fixtures/media/image.jpg

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T57_deepseek_logo_identification`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
