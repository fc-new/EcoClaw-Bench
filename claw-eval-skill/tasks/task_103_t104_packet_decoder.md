---
id: task_103_t104_packet_decoder
name: Claw-Eval T104_packet_decoder
category: terminal
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/103_00_t104_packet_decoder.bin
    dest: capture.bin
  - source: assets/claw_eval/103_01_t104_packet_decoder.md
    dest: protocol_spec.md
---

## Prompt

Container files:

- /workspace/fixtures/capture.bin — binary stream of protocol packets
- /workspace/fixtures/protocol_spec.md — protocol specification

Write /workspace/decode.py that parses all packets from capture.bin
and outputs /workspace/decoded.jsonl (one JSON object per line).

The spec may be incomplete in places — examine the actual binary data
to resolve any ambiguities.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T104_packet_decoder`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
