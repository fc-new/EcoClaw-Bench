---
id: task_100_t101_wal_recovery
name: Claw-Eval T101_wal_recovery
category: terminal
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/100_00_t101_wal_recovery.db
    dest: test.db
  - source: assets/claw_eval/100_01_t101_wal_recovery.db-wal
    dest: test.db-wal
---

## Prompt

Container files:

- /workspace/fixtures/test.db — SQLite database in WAL mode
- /workspace/fixtures/test.db-wal — WAL (Write-Ahead Logging) file, appears corrupted

The database should contain 11 records total, but when you query it
with SQLite, you only see 5 base records. The WAL file contains
updates to 2 existing records and 6 new inserts, but SQLite refuses
to apply the WAL frames.

Your task is to:
1. Diagnose why SQLite ignores the WAL frames
2. Fix the WAL file so SQLite can read all frames
3. Verify the database now returns all 11 records
4. Write /workspace/recovered.json with all records

Output format for recovered.json:
[{"id": 1, "name": "...", "value": N.N}, ...]
sorted by id. You should recover all 11 records total.

Hint: The WAL format is documented in the SQLite file format spec.
Pay attention to the relationship between the WAL header and frame
headers — specifically the salt values that SQLite uses to validate
frames.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T101_wal_recovery`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
