---
id: task_133_t134_video_snack_checklist
name: Claw-Eval T134_video_snack_checklist
category: video_image
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/133_00_t134_video_snack_checklist.mp4
    dest: video.mp4
---

## Prompt

容器里有以下文件：
- /workspace/fixtures/video.mp4

请浏览这段 vlog，把其中出现的所有零食都截图下来（截图里零食的名称或包装要清晰可见），每种零食截一张最清晰的，同一零食不用重复截。在每张截图下标注零食名称，优先写英文，没有英文的话写中文。最后把所有截图和名称整合成一张美食打卡清单图片，输出为 /workspace/snack_checklist.jpg。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `multimodal`
Original task id: `T134_video_snack_checklist`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate this snack checklist image from a vlog:

Ground truth snacks (6 total):
1. Rice Cracker with Pork Floss
2. Mango Jelly
3. Mango Flavour Soft Candy
4. 榴莲软糖 (Durian Soft Candy)
5. Crispy Thai Coconut Milk
6. Thai Coconut Caramel

Evaluation criteria:

1. Snack image recall (0.35):
   Check how many of the 6 snacks have a clear photo/screenshot in the image.
   Score = (number found) / 6 * 0.35.

2. Label matching (0.35):
   Check how many snacks have correct text labels (name annotations) visible outside the product images. English preferred, Chinese acceptable for 榴莲软糖.
   Score = (number correctly labeled) / 6 * 0.35.

3. Checklist style (0.3):
   - Does it look like a food/snack checklist or collection card? (0.15)
   - Is the layout organized with clear grid/cards? (0.15)

Score 0.0-1.0 based on weighted sum of all criteria.
