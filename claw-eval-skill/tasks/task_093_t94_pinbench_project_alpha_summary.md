---
id: task_093_t94_pinbench_project_alpha_summary
name: Claw-Eval T94_pinbench_project_alpha_summary
category: synthesis
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/093_00_t94_pinbench_project_alpha_summary.json
    dest: inbox.json
---

## Prompt

Search the Gmail inbox for everything related to Project Alpha and produce a
structured summary with these sections:
1. Project Overview
2. Timeline
3. Key Risks and Issues
4. Client and Business Impact
5. Current Status
Ignore unrelated noise emails.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T94_pinbench_project_alpha_summary`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
