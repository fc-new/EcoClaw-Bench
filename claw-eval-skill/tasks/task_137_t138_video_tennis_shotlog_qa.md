---
id: task_137_t138_video_tennis_shotlog_qa
name: Claw-Eval T138_video_tennis_shotlog_qa
category: video_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/137_00_t138_video_tennis_shotlog_qa.webm
    dest: video.webm
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.webm

I have uploaded a video clip showing a specific game from a tennis match between Andy Murray and Roger Federer.
Please carefully watch the footage and locate the exact point that begins when the score is Set 0:1, Game 4:5, and Point 0:15. Please answer the following four questions sequentially.
First, identify which player is serving to start this point.
Second, provide a chronological, shot-by-shot log of the entire rally. Starting from the return of serve, explicitly specify the name of the player hitting the ball and whether they used a forehand or a backhand stroke for every single shot.
Third, count and state the exact total number of shots hit during this entire point, including the initial serve.
Fourth, clearly state the name of the player who ultimately won this specific point.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T138_video_tennis_shotlog_qa`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth (point at Set 0:1, Game 4:5, Point 0:15):

1. Server (0.1): Andy Murray is serving. Score 0.1 if correct, 0 otherwise.

2. Shot-by-shot log (0.5):
   Ground truth rally sequence (after the serve):
   - Roger Federer - backhand
   - Andy Murray - forehand
   - Roger Federer - backhand
   - Andy Murray - forehand
   - Roger Federer - forehand

   Scoring breakdown:
   - Player sequence correctness (0.25): The sequence of player names hitting the ball must be correct: Federer, Murray, Federer, Murray, Federer. If the player sequence is wrong, the entire shot log scores 0.
   - Stroke type correctness (0.25): For each of the 5 return shots, score 0.05 if the stroke type (forehand/backhand) is correct. Only scored if the player sequence is correct.

3. Total shot count (0.2): 6 shots (including the serve). Score 0.2 if exactly correct, 0 otherwise.

4. Point winner (0.2): Roger Federer wins the point. Score 0.2 if correct, 0 otherwise.

Final score = sum of all items (0.0-1.0).
