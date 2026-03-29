---
id: task_127_t128_video_factory_promo_webpage
name: Claw-Eval T128_video_factory_promo_webpage
category: video_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/127_00_t128_video_factory_promo_webpage.mp4
    dest: video.mp4
---

## Prompt

容器里有以下文件：
- /workspace/fixtures/video.mp4

老板让我给咱们工厂做个宣传页，正好看到这段拍我们生产线的视频。帮我从视频里把关键信息整理出来：生产的是什么东西？用了什么核心技术或制作工艺？这个东西有哪些优良的性能？视频里有没有出现产能数据？视频有没有字幕说明？然后做个内容详细丰富的中文宣传单页HTML，保存为 /workspace/output.html，风格要工业感但现代。整体要配色和谐、审美在线。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `multimodal`
Original task id: `T128_video_factory_promo_webpage`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth (5 questions, each worth 0.1, total 0.5 mapped to 1.0 in judge):

1. Product (0.2): 复合耐磨钢板 (composite wear-resistant steel plate).
2. Core Technology (0.2): 明弧自保护全自动堆焊技术 (open-arc self-shielded fully automatic surfacing welding).
3. Performance (0.2): 优良的抗疲劳性能、抗冲击性能和耐腐蚀性能 (fatigue resistance, impact resistance, corrosion resistance).
4. Production Data (0.2): 字幕中完全没有出现任何关于产能、产量或生产速度的数据 (no production capacity data in subtitles).
5. Subtitles (0.2): 视频包含字幕 (video contains subtitles).

Score each item 0.2 if correct, 0 if wrong. Sum all items for final score 0.0-1.0.

===RUBRIC===

Evaluate this factory promotional webpage:
- Is the HTML generated and does it render properly? (0.2)
- Industrial + modern style (dark/metallic tones, clean layout)? (0.2)
- Content detailed and rich (product info, technology, performance)? (0.2)
- Content matches the video subtitles accurately, no fabrication? (0.2)
- Color harmony, layout aesthetics, overall visual appeal? (0.2)

Score 0.0-1.0 based on weighted sum of criteria.
