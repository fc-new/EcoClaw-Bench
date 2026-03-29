---
id: task_001_t02_email_triage
name: Claw-Eval T02_email_triage
category: communication
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/001_00_t02_email_triage.json
    dest: inbox.json
---

## Prompt

Sort my inbox — which emails need a reply, which are notifications, and which are spam?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T02_email_triage`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

prompt = (
"Given the assistant's response below, determine what email category "
"was assigned to each email.\n\n"
"For each email output EXACTLY one of:\n"
'  "needs reply" — the assistant indicated this email requires a reply or action\n'
'  "FYI"         — the assistant indicated this is a notification / informational email\n'
'  "spam"        — the assistant indicated this is spam or junk\n'
'  "unmentioned" — the email was not mentioned or no category was assigned\n\n'
f"Emails:\n{email_list}\n\n"
f"Assistant's response:\n{final_text}\n\n"
'Output JSON only, msg_ids as keys, e.g. {"msg_001": "needs reply", ...}'
)
