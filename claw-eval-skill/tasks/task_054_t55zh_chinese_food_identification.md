---
id: task_054_t55zh_chinese_food_identification
name: Claw-Eval T55zh_chinese_food_identification
category: OCR
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/054_00_t55zh_chinese_food_identification.jpg
    dest: image.jpg
---

## Prompt

这是什么吃的

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T55zh_chinese_food_identification`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
