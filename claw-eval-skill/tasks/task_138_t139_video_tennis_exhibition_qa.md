---
id: task_138_t139_video_tennis_exhibition_qa
name: Claw-Eval T139_video_tennis_exhibition_qa
category: video_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/138_00_t139_video_tennis_exhibition_qa.webm
    dest: video.webm
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.webm

I am compiling statistics for a special Australian Open exhibition event featuring sudden-death, one-point matches between amateur challengers and professional tennis players. Please carefully watch the uploaded video clip and provide a detailed breakdown based strictly on the visual and audio evidence. First, explicitly state the total number of amateur versus professional matches played in this specific footage. Second, for each individual match shown, please outline the following four details in chronological order: the names of the two players competing, a clear identification of which player is the amateur, the name of the player who served the ball to start the point, and the name of the player who ultimately won the match.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T139_video_tennis_exhibition_qa`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth: 3 amateur vs professional matches.

1. Total match count (0.1): Must state exactly 3 matches. Score 0.1 if correct.

2. Match 1 — Jovic vs Medvedev (0.3):
   - Players: Jovic and Medvedev (0.075)
   - Amateur: Jovic is the amateur (0.075)
   - Server: Jovic served (0.075)
   - Winner: Medvedev wins (0.075)

3. Match 2 — Yarwood vs Kyrgios (0.3):
   - Players: Yarwood and Kyrgios (0.075)
   - Amateur: Yarwood is the amateur (0.075)
   - Server: Yarwood served (0.075)
   - Winner: Kyrgios wins (0.075)

4. Match 3 — Garland vs Smith (0.3):
   - Players: Garland and Smith (0.075)
   - Amateur: Smith is the amateur (0.075)
   - Server: Garland served (0.075)
   - Winner: Smith wins (0.075)

Final score = sum of all items (0.0-1.0).
Matches must be in chronological order as they appear in the video.
