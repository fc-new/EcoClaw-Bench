---
id: task_087_t88_pinbench_project_bootstrap_plan
name: Claw-Eval T88_pinbench_project_bootstrap_plan
category: file_ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/087_00_t88_pinbench_project_bootstrap_plan.json
    dest: tasks.json
---

## Prompt

Instead of creating files directly, use the todo service to bootstrap a Python
library project plan for "datautils". Create actionable tasks for:
1. creating the package structure under src/datautils
2. adding tests
3. writing pyproject metadata
4. writing a README
Then summarize the setup plan.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T88_pinbench_project_bootstrap_plan`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
