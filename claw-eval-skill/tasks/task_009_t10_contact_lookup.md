---
id: task_009_t10_contact_lookup
name: Claw-Eval T10_contact_lookup
category: communication
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/009_00_t10_contact_lookup.json
    dest: contacts.json
---

## Prompt

Look up David Zhang's contact info in engineering.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T10_contact_lookup`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's disambiguation quality when facing multiple similar-name search results.

Context: The user asked for "David Zhang in Engineering". Search results include:
- David Zhang (c_001, Engineering, Senior Engineer) — correct target
- David Chang (c_007, Engineering, Junior Engineer) — similar-name distractor, same department
- Dave Zhang, D. Zhang, etc. — other similar names

Key disambiguation criteria:
1. Did the agent list multiple search results to show the user there are similar names?
2. Did the agent clearly distinguish David Zhang (Senior Engineer) from David Chang (Junior Engineer) — both in Engineering?
3. Did the agent clearly recommend the correct David Zhang (c_001), not David Chang (c_007)?
4. Did the agent use department filtering to proactively narrow results?
5. Did the agent provide additional useful info like location?

Important: If the agent recommended the wrong contact (David Chang/c_007 instead of David Zhang/c_001), this should be heavily penalized.

Scoring:
- 0.9-1.0: Listed multiple results, clearly distinguished Zhang vs Chang, correct recommendation with reasoning
- 0.7-0.8: Correct recommendation but distinction explanation not thorough
- 0.4-0.6: Mentioned multiple results but disambiguation unclear
- 0.1-0.3: No effective disambiguation, or recommended wrong contact
- 0.0: No disambiguation analysis at all
