---
id: task_129_t130_video_story_interactive_webpage
name: Claw-Eval T130_video_story_interactive_webpage
category: video_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/129_00_t130_video_story_interactive_webpage.mp4
    dest: video.mp4
---

## Prompt

容器里有以下文件：
- /workspace/fixtures/video.mp4

视频里讲的这个故事好有意思啊，你帮我做一个有趣的网页帮小朋友介绍这个故事吧，里面要有每个人物（头像），讲清楚故事的脉络，然后最后再包含一个小游戏，寓教于乐。要求网页布局合理，配色和谐明快。保存为 /workspace/output.html。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `multimodal`
Original task id: `T130_video_story_interactive_webpage`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth: The story is 田忌赛马 (Tian Ji's Horse Racing). Main characters: 齐威王, 田忌, 孙膑.

Scoring (total 1.0, will be weighted 0.3 in final):

1. Story accuracy (0.5):
   - Must accurately convey the core logic: inferior horses vs superior horses, rearranging the order of matchups, ultimately winning by losing one and winning two.
   - No fabricated plots.

2. Character identification (0.5):
   - Must correctly identify all 3 characters: 齐威王, 田忌, 孙膑.
   - Must include character avatars/visual representation on the page.
   - Missing characters or no avatars = proportional deduction.

Score 0.0-1.0.

===RUBRIC===

Evaluate this educational webpage about the 田忌赛马 (Tian Ji's Horse Racing) story:

1. Story presentation with character avatars (0.2):
   - Characters (齐威王, 田忌, 孙膑) shown with avatar images/icons.
   - Story flow is clear and follows the narrative.

2. Interactive game (0.3):
   - Contains a truly interactive mini-game (not just static text/images).
   - Game has click/drag interaction, start button, game logic.
   - Game relates to the horse racing strategy theme.

3. Child-friendly design (0.25):
   - Language is lively and fun, appropriate for children.
   - No obscure classical Chinese or dry encyclopedia style.

4. UI/UX layout and color (0.25):
   - Layout is well-organized: text, avatars, game area clearly separated.
   - Colors are bright, harmonious, and cheerful.
   - No overlapping elements, good readability.

Score 0.0-1.0 based on weighted criteria.
