---
id: task_136_t137_video_tennis_breakpoint_qa
name: Claw-Eval T137_video_tennis_breakpoint_qa
category: video_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/136_00_t137_video_tennis_breakpoint_qa.webm
    dest: video.webm
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.webm

I am analyzing a specific video clip of Novak Djokovic playing in a fifth set. Please watch the uploaded video carefully and answer the following questions based solely on the visual and audio events shown in this exact footage.
To ensure we are on the same page, here are the definitions of the tennis terms you will need for this task:
Break Point: A situation where the receiving player is one point away from winning the game on the server's serve (for example, when the point score is 0:40, 15:40, 30:40, or Advantage for the receiver). Saving a break point means Djokovic wins that specific point to keep the game alive.
Winner: A proactive, successful shot hit by a player that lands in the court and cannot be touched or returned by the opponent, resulting in a direct point.
Error: A failed shot by a player that either lands out of bounds or hits the net, gifting the point to the opponent.
First, please state the exact total number of break points Djokovic successfully saved during the fifth set within this specific video clip.
Second, provide a chronological breakdown for each of those saved break points. For every single break point, you must provide the following three specific details: The game score and the point score right before the point starts, such as 2:1 15:30. The exact video timestamp when the break point starts. A clear specification of how Djokovic saved the point, explicitly stating whether it was a Djokovic winner or an opponent error.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T137_video_tennis_breakpoint_qa`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth:

Djokovic saved 2 break points in the fifth set in this video.

Break Point 1:
- Game score: 1:2, Point score: 15:40
- Video timestamp: approximately 2:23
- Resolution: Djokovic's winner

Break Point 2:
- Game score: 4:3, Point score: 15:40
- Video timestamp: approximately 2:36
- Resolution: Djokovic's winner

Scoring:
1. Total break point count (0.2): Must state exactly 2. Score 0.2 if correct, 0 otherwise.

2. Break Point 1 details (0.4):
   - Game score correct "1:2" (0.1)
   - Point score correct "15:40" (0.1)
   - Timestamp approximately correct within ±5s of 2:23 (0.1)
   - Resolution correct "Djokovic's winner" (0.1)

3. Break Point 2 details (0.4):
   - Game score correct "4:3" (0.1)
   - Point score correct "15:40" (0.1)
   - Timestamp approximately correct within ±5s of 2:36 (0.1)
   - Resolution correct "Djokovic's winner" (0.1)

Final score = sum of all items (0.0-1.0).
