---
id: task_000_t01zh_email_triage
name: Claw-Eval T01zh_email_triage
category: communication
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/000_00_t01zh_email_triage.json
    dest: inbox.json
---

## Prompt

帮我分一下邮箱，哪些要回、哪些是通知、哪些是垃圾邮件。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T01zh_email_triage`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

prompt = (
"Given the assistant's response below, determine what email category "
"was assigned to each email.\n\n"
"For each email output EXACTLY one of:\n"
'  "需回复"   — the assistant indicated this email needs a reply or action\n'
'  "仅供参考" — the assistant indicated this is a notification / FYI email\n'
'  "垃圾邮件" — the assistant indicated this is spam or junk\n'
'  "未提及"   — the email was not mentioned or no category was assigned\n\n'
f"Emails:\n{email_list}\n\n"
f"Assistant's response:\n{final_text}\n\n"
'Output JSON only, msg_ids as keys, e.g. {"msg_001": "需回复", ...}'
)
