---
id: task_135_t136_video_tennis_rally_qa
name: Claw-Eval T136_video_tennis_rally_qa
category: video_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/135_00_t136_video_tennis_rally_qa.webm
    dest: video.webm
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.webm

I am conducting a detailed statistical analysis of historic, extended tennis rallies. Please watch the provided video clip of a grueling point and answer the following six questions in sequence based purely on the visual footage.
First, identify the two players competing in this point. Second, which set is this match currently in? Third, what is the exact game score and point score right before the point starts? Fourth, what is the updated game score immediately after this point concludes? Fifth, which player ultimately wins this specific point? Sixth, please carefully track the ball and count every single stroke. Exactly how many shots were hit in total during this entire rally?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T136_video_tennis_rally_qa`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth (6 items):

1. Players (0.1): Djokovic vs Nadal. Both names must be correct.
2. Set (0.1): Second set. Must state "second set" or "2nd set".
3. Score before point (0.1): Game score 3:2, point score 40:30. Both game score and point score must be correct.
4. Score after point (0.1): Game score 4:2. Must be correct.
5. Point winner (0.1): Djokovic wins the point. Must name Djokovic.
6. Total shots in rally (0.5): 54 shots.
   - Exact (54): 0.5
   - Within ±3 (51-57): 0.4
   - Within ±5 (49-59): 0.3
   - Within ±10 (44-64): 0.2
   - Within ±15 (39-69): 0.1
   - Beyond ±15: 0.0

Final score = sum of all items (0.0-1.0).
