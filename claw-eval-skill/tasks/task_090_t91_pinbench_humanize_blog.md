---
id: task_090_t91_pinbench_humanize_blog
name: Claw-Eval T91_pinbench_humanize_blog
category: rewriting
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/090_00_t91_pinbench_humanize_blog.txt
    dest: ai_blog.txt
---

## Prompt

Rewrite the attached blog post so it sounds more natural and human-written while
keeping the same ideas. Reduce robotic transitions like "Furthermore" and
"It is important to note", and keep the advice about prioritization, reducing
distractions, time blocking, breaks, and work-life balance.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T91_pinbench_humanize_blog`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
