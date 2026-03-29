---
id: task_102_t103_schema_migration
name: Claw-Eval T103_schema_migration
category: terminal
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/102_00_t103_schema_migration.sql
    dest: old_schema.sql
  - source: assets/claw_eval/102_01_t103_schema_migration.sql
    dest: new_schema.sql
  - source: assets/claw_eval/102_02_t103_schema_migration.db
    dest: test_data.db
---

## Prompt

Container files:

- /workspace/fixtures/old_schema.sql — current (legacy) database schema
- /workspace/fixtures/new_schema.sql — target schema
- /workspace/fixtures/test_data.db — SQLite database with legacy data

Write /workspace/migrate_data.py that transforms test_data.db from the old
schema to the new schema. The migrated database must match the new schema
exactly and preserve all data correctly. Handle any data quality issues
appropriately to satisfy the new schema constraints.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T103_schema_migration`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
