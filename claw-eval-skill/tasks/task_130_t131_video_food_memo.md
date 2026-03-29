---
id: task_130_t131_video_food_memo
name: Claw-Eval T131_video_food_memo
category: video_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/130_00_t131_video_food_memo.mp4
    dest: video.mp4
---

## Prompt

容器里有以下文件：
- /workspace/fixtures/video.mp4

河南的美食真不错，看这个视频帮我写个markdown格式的备忘录。把视频里出现的每一道美食的名称、视频中的相应传承人的姓名以及是第几代、美食的制作方法、美食的口感整理好。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `multimodal`
Original task id: `T131_video_food_memo`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth (2 foods from the video):

1. 百年白记 花生糕 (Peanut Cake):
   - Craftsman: 第三代传承人白凤奇 (3rd generation, Bai Fengqi)
   - Method: 熬糖, 拌料, 层层叠压, 擀平, 横撕竖拉, 最后成型 (boil sugar, mix ingredients, layer and press, roll flat, tear horizontally and vertically, final shaping)
   - Taste: 酥香绵甜, 入口即化 (crispy, fragrant, soft-sweet, melts in mouth)

2. 齐氏大刀面 (Qi's Big Knife Noodles):
   - Craftsman: 第八代传承人齐同库 (8th generation, Qi Tongku)
   - Method: 大铡刀切面, 入锅3秒就熟 (cut with big chopper, cooked in 3 seconds)
   - Taste: 清香松软, 光滑利口, 劲道 (fragrant, soft, smooth, chewy)

Scoring:
- Markdown format (0.2): Output uses proper markdown formatting (headers, lists, etc.).
- Food 1 (0.4): Name (0.1) + Craftsman name and generation (0.1) + Method (0.1) + Taste (0.1).
- Food 2 (0.4): Name (0.1) + Craftsman name and generation (0.1) + Method (0.1) + Taste (0.1).

For method and taste, partial credit is allowed (not all-or-nothing).
Final score = sum of all parts (0.0-1.0).
