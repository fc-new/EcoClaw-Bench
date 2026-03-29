---
id: task_120_t121_video_subtitle_ocr_timestamp
name: Claw-Eval T121_video_subtitle_ocr_timestamp
category: video_ocr
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/120_00_t121_video_subtitle_ocr_timestamp.webm
    dest: video.webm
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.webm

I'm currently editing a video and need your help extracting the Chinese
subtitles from the first 30 seconds of this clip. Please identify the
precise appearance and disappearance times for each line, using seconds
as the unit and rounding to one decimal place (e.g., 1.5). Once you have
the data, please save it directly into a file named /workspace/subtitles.jsonl,
requiring each line to be an independent JSON object in the following format:
{"start": 0.0, "end": 0.7, "text": "内容"}.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T121_video_subtitle_ocr_timestamp`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth (22 subtitle entries):
{"start": 0.7, "end": 1.2, "text": "朋友们"}
{"start": 1.2, "end": 2.1, "text": "不知道你有没有意识到"}
{"start": 2.1, "end": 3.8, "text": "美元今年是跌惨了"}
{"start": 5.1, "end": 6.6, "text": "上半年是近半个世纪"}
{"start": 6.6, "end": 7.8, "text": "表现最差的一年"}
{"start": 7.8, "end": 8.5, "text": "从年初到现在"}
{"start": 8.5, "end": 10.5, "text": "美元指数已经下跌了超过10%"}
{"start": 10.5, "end": 11.7, "text": "你别觉得10%没多少啊"}
{"start": 11.7, "end": 12.6, "text": "这可是美元"}
{"start": 12.6, "end": 13.5, "text": "不是什么比特币"}
{"start": 13.5, "end": 15.0, "text": "这是全球资产的标尺"}
{"start": 15.0, "end": 17.5, "text": "这个尺子半年里头缩短了10%"}
{"start": 17.5, "end": 19.3, "text": "约等于所有人都长高了10%"}
{"start": 19.3, "end": 20.0, "text": "与此同时"}
{"start": 20.0, "end": 22.3, "text": "全球的资产价格都出现了久违的爆发"}
{"start": 22.3, "end": 23.4, "text": "最猛的就是黄金"}
{"start": 23.4, "end": 24.2, "text": "你就看这张图"}
{"start": 24.2, "end": 25.8, "text": "这是过去半个世纪黄金的走势"}
{"start": 25.8, "end": 27.4, "text": "我只能用疯狂来形容"}
{"start": 27.4, "end": 28.7, "text": "比特币也是创出了新高"}
{"start": 28.7, "end": 29.1, "text": "也疯狂"}
{"start": 29.1, "end": 30.7, "text": "不过它可能一直都挺疯狂"}

Scoring rules:
The task starts with a base score of 1.0 based on the 22 ground truth entries.
A line is marked Correct only if:
  1. The text matches the GT (ignoring punctuation), AND
  2. The time interval achieves an IoU > 0.5 with the GT interval.
     IoU = intersection / union of the two time intervals.

For each missing, hallucinated, or incorrect entry, deduct 0.1 points (minimum 0.0).

Evaluate the JSONL output against the ground truth using these criteria.
Output a score between 0.0 and 1.0.
