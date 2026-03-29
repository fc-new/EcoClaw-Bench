---
id: task_003_t04_calendar_scheduling
name: Claw-Eval T04_calendar_scheduling
category: productivity
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/003_00_t04_calendar_scheduling.json
    dest: events.json
---

## Prompt

Schedule a project sync with Mike and Sarah on 2026-03-02 (Monday), ~1 hour, find a free slot.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T04_calendar_scheduling`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's scheduling analysis quality and whether the created event has an appropriate title.

Part 1 — Scheduling analysis (primary):
1. Showed each attendee's calendar conflicts (when Mike, Sarah, and the user are busy)
2. Identified which time slots are free for all participants
3. Explained why the chosen time slot was selected (e.g., "14:30-15:30 works for everyone")
4. Referenced specific calendar events as reasons for avoidance

Core test: Did the agent show a complete "check conflicts → find free slots → pick best option" analysis flow, rather than just picking a time without explanation?

Part 2 — Event title (secondary):
- The created calendar event title should relate to "project sync"
- Acceptable titles: Project Sync, Project Sync Meeting, Team Sync, etc.
- Title should reflect the "project sync" theme

Scoring:
- 0.9-1.0: Complete scheduling analysis (conflicts, free slots, selection rationale), and appropriate event title
- 0.7-0.8: Analysis mostly complete with minor gaps, appropriate title
- 0.5-0.6: Analysis incomplete, or title not quite relevant
- 0.2-0.4: Only briefly mentioned a time, lacking analysis process
- 0.0-0.1: No scheduling analysis at all
