---
id: task_051_t52_su7_price_from_image
name: Claw-Eval T52_su7_price_from_image
category: OCR
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/051_00_t52_su7_price_from_image.jpg
    dest: su7_image_old.jpg
---

## Prompt

How much does this car sell for now?
Please use the attached image. If exact pricing is uncertain, provide a plausible range and explain why.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T52_su7_price_from_image`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the assistant correctly identified the car and provided a plausible price range.

The correct answer is that the image shows a Xiaomi SU7 (老款/launch era).
Key facts the response should contain:
- Car model: Xiaomi SU7 (小米SU7)
- Price range: approximately 21.59万元 (Standard) / 24.59万元 (Pro) / 29.99万元 (Max)
- Uncertainty handling: acknowledges trim/version/year ambiguity, avoids overclaiming exact price from image alone

Scoring guidance:
- 0.90-1.00: Correctly identifies Xiaomi SU7, gives realistic price range, explains uncertainty.
- 0.70-0.89: Correct model and approximate price with minor gaps.
- 0.40-0.69: Identifies car but price range is vague or missing uncertainty explanation.
- 0.00-0.39: Wrong model, wildly incorrect price, or no meaningful answer.
