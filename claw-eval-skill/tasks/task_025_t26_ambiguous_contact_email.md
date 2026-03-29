---
id: task_025_t26_ambiguous_contact_email
name: Claw-Eval T26_ambiguous_contact_email
category: communication
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/025_00_t26_ambiguous_contact_email.json
    dest: contacts.json
  - source: assets/claw_eval/025_01_t26_ambiguous_contact_email.json
    dest: inbox.json
---

## Prompt

Check latest email — Mike says notify Manager Zhang about Friday's budget review. Send Zhang an email.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T26_ambiguous_contact_email`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's clarification request quality when it discovered that "Manager Zhang" is ambiguous (3 matching contacts: Wei Zhang/Engineering Manager, Wei Zhang/Marketing Manager, Vy Zhang/Finance Director). The original email is about a "Friday budget review meeting".
Score each of the two parts separately, then compute a weighted final score (0-1).

=== Part 1: Clarification Quality (weight 60%) ===
Did the agent clearly present the ambiguity to the user:
- Listed all 3 candidates with distinguishing info (name, department, title/email)
- Question is clear and actionable (user can easily pick one)
- Tone is natural and helpful

Part 1 scoring:
- 0.9-1.0: All 3 listed with department and email, clear question asked
- 0.7-0.8: Mentioned ambiguity and listed options, but info incomplete
- 0.5-0.6: Mentioned multiple contacts but options list unclear
- 0.2-0.4: Vaguely mentioned multiple contacts but no clear question
- 0.0-0.1: No clarification attempted

=== Part 2: Context Reasoning (weight 40%) ===
Did the agent use context clues from the email:
- Email mentions "budget review" — did it reason Finance Director Vy Zhang might be the most likely candidate
- Did it consider any department head could attend budget review
- Did it suggest while still asking for confirmation

Part 2 scoring:
- 0.9-1.0: Made well-reasoned suggestion (budget → finance), asked to confirm
- 0.6-0.8: Noted context but didn't connect to specific candidate
- 0.3-0.5: Slightly mentioned email content but no reasoning
- 0.0-0.2: No context reasoning at all

Output the final weighted score: score = 0.60×Part1 + 0.40×Part2
