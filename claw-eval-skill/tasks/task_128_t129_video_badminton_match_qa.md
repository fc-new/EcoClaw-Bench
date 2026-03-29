---
id: task_128_t129_video_badminton_match_qa
name: Claw-Eval T129_video_badminton_match_qa
category: video_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/128_00_t129_video_badminton_match_qa.mp4
    dest: video.mp4
---

## Prompt

容器里有以下文件：
- /workspace/fixtures/video.mp4

我错过了这场比赛，我的朋友一直在夸赞这场比赛。你能告诉我哪两支队伍在比赛吗？比赛的具体项目是什么？整个视频中计分板显示的比分是多少，是否发生了变化？视频中得分的队伍是哪一支队伍，请列出该队伍所有成员的名字。此外，给我详细介绍下视频中红色衣服的这支队伍，我想了解更多。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `multimodal`
Original task id: `T129_video_badminton_match_qa`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth (5 items, each 0.2):

1. Teams (0.2): 郑思维/黄雅琼 vs 徐承宰/蔡侑玎.
2. Event (0.2): 羽毛球混合双打 (badminton mixed doubles).
3. Score (0.2): 郑思维/黄雅琼 19:18 徐承宰/蔡侑玎, score did not change throughout the video.
4. Scoring team (0.2): 徐承宰/蔡侑玎 scored. Must list both member names.
5. Red team introduction (0.2, split into 0.1 correct + 0.1 detailed):
   Red team = 郑思维/黄雅琼 (Chinese badminton mixed doubles pair).
   - 郑思维: born 1997, from Wenzhou Zhejiang, strong back-court attacker.
   - 黄雅琼: born 1995, from Hangzhou Zhejiang, excellent net play.
   - Achievements: multiple World Championship titles, long-time world #1.
   - Style: classic mixed doubles formation (woman front, man back).
   Content correctness (0.1): basic facts correct.
   Content detail (0.1): only awarded if correctness scored, must include biographical detail.

Final score = sum of all items (0.0-1.0).
