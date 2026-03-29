---
id: task_119_t120_video_subtitle_ocr_chinese_filter
name: Claw-Eval T120_video_subtitle_ocr_chinese_filter
category: video_ocr
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/119_00_t120_video_subtitle_ocr_chinese_filter.webm
    dest: video.webm
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.webm

我正在分析黄金，请你帮我把视频中讲解问题二"为什么白银涨得比黄金猛"的视频片段中所有出现了"黄金"的句子找出来（每一条字幕算一个句子），放进一个列表里。最后答案写在一个txt文件 /workspace/output.txt 里，一行一句话，不要加任何标点符号。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `multimodal`
Original task id: `T120_video_subtitle_ocr_chinese_filter`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth sentences (10 items):
1. 看历史上黄金和白银的价格走势
2. 大概是黄金的两倍左右
3. 它上涨是黄金的两倍
4. 下跌是黄金的两倍
5. 白银是比黄金要大一个数量级的
6. 白银是要比黄金小一个数量级
7. 黄金就像是一艘航母
8. 黄金市场显然太大了
9. 很多人感觉黄金是不是太贵了呀
10. 白银肯定比黄金更刺激

Start with a base score of 1.0. Apply the following deductions (minimum score 0.0):
- -0.1 pts for each sentence in the Ground Truth that is missing from the output.
- -0.1 pts for each extra sentence included in the output that is NOT in the Ground Truth.

Evaluate the output text against the ground truth using the criteria above.
Output a score between 0.0 and 1.0.
