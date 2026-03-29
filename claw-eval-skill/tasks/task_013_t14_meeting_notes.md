---
id: task_013_t14_meeting_notes
name: Claw-Eval T14_meeting_notes
category: productivity
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/013_00_t14_meeting_notes.json
    dest: meetings.json
---

## Prompt

Summarize the February 23, 2026 weekly meeting key points and send to attendees.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T14_meeting_notes`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's quality in extracting action items and key information from meeting notes.
Score each of the three parts separately, then compute a weighted final score (0-1).

=== Part 1: Action Item Extraction (weight 60%) ===
The 5 action items that should be extracted:
1. Zhao Qiang: fix bug, due Friday
2. Li Ming: tech review, due Wednesday
3. Wang Fang: impact assessment, due Monday
4. Li Ming: ERP-related task
5. Manager Zhang: requirements review, due next week

Each action item should include: assignee, task description, deadline (if any).

Part 1 scoring:
- 0.9-1.0: All 5 action items correctly extracted with assignees and deadlines
- 0.7-0.8: 4 items extracted, or 5 but some missing deadlines
- 0.5-0.6: 3 items extracted
- 0.3-0.4: 1-2 items extracted
- 0.0-0.2: Almost no action items extracted

=== Part 2: Carryover Item Identification (weight 20%) ===
- Wang Fang's "update user persona document" from last week's meeting (note_004) is still in progress
- The agent should identify this as unfinished carryover work

Part 2 scoring:
- 0.9-1.0: Clearly identified the carryover item, noted it's from last week and still incomplete
- 0.4-0.8: Mentioned user persona content but didn't explicitly mark as carryover/incomplete
- 0.0-0.3: No mention of the carryover item at all

=== Part 3: Excluding Casual Content (weight 20%) ===
- Notes contain casual chat (learn Rust, hiking, vase, cat, talent show, etc.)
- A good summary should only include work-related action items

Part 3 scoring:
- 1.0: No casual content listed as action items or to-dos
- 0.5: Mentioned casual content but distinguished it (e.g., labeled "non-work")
- 0.0: Listed casual content (learn Rust, hiking, etc.) as formal action items

Output the final weighted score: score = 0.6×Part1 + 0.2×Part2 + 0.2×Part3
