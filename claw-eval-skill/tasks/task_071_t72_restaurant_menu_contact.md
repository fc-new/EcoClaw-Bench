---
id: task_071_t72_restaurant_menu_contact
name: Claw-Eval T72_restaurant_menu_contact
category: OCR
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/071_00_t72_restaurant_menu_contact.jpeg
    dest: menu.jpeg
  - source: assets/claw_eval/071_01_t72_restaurant_menu_contact.txt
    dest: menu_ocr.txt
---

## Prompt

hey my friend sent me a menu fixtures/media/menu.jpeg . looks good and i want to know the contact number to book.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T72_restaurant_menu_contact`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the accuracy and completeness of contact information extracted from the restaurant menu.

CONTACT INFORMATION (at least one of the 3 locations is required):

Location 1:
- Address: No. 23 Jervois St., Sheung Wan, Hong Kong (上環蘇杭街23號地下)
- Phone: +852 2234 0080

Location 2:
- Address: No. 68 Stone Nullah Ln., Wanchai, Hong Kong (香港灣仔石水渠街68號地下)
- Phone: +852 2234 0001

Location 3:
- Address: No. 18 On Lan Street, Central, Hong Kong (中環安蘭街18號地下)
- Phone: +852 2234 0010

SCORING:
- 0.90-1.00: all 3 phone numbers correct
- 0.60-0.89: 2 of 3 phone numbers correct
- 0.30-0.59: 1 of 3 phone numbers correct
- 0.00-0.29: no correct phone numbers
