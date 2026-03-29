---
id: task_099_t100_reverse_decoder
name: Claw-Eval T100_reverse_decoder
category: terminal
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/099_00_t100_reverse_decoder.py
    dest: decoder.py
  - source: assets/claw_eval/099_01_t100_reverse_decoder.txt
    dest: target.txt
---

## Prompt

Container files:

- /workspace/fixtures/decoder.py — reads encoded binary from stdin, writes decoded text to stdout
- /workspace/fixtures/target.txt — desired output text

Create /workspace/encoded.dat such that:
  python /workspace/fixtures/decoder.py < /workspace/encoded.dat
produces output that exactly matches target.txt.

Size constraint: encoded.dat must be at most 60% the size of target.txt in bytes.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T100_reverse_decoder`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
