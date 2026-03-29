---
id: task_012_t13zh_meeting_notes
name: Claw-Eval T13zh_meeting_notes
category: productivity
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/012_00_t13zh_meeting_notes.json
    dest: meetings.json
---

## Prompt

帮我把2026年2月23日周会的要点整理出来，发给参会的人。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T13zh_meeting_notes`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent从会议记录中提取行动项和关键信息的质量。
请分别评估以下三个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：行动项提取（权重60%）===
应该提取的5个行动项：
1. 赵强：修复bug，截止周五
2. 李明：技术评审，截止周三
3. 王芳：影响范围评估，截止周一
4. 李明：ERP相关任务
5. 张经理：需求评估，截止下周

每个行动项应包含：负责人、任务内容、截止日期（如有）。

本部分评分标准：
- 0.9-1.0: 全部5个行动项均正确提取，负责人和截止日期完整
- 0.7-0.8: 提取了4个行动项，或5个但部分缺少截止日期
- 0.5-0.6: 提取了3个行动项
- 0.3-0.4: 提取了1-2个行动项
- 0.0-0.2: 几乎没有提取行动项

=== 第二部分：遗留项识别（权重20%）===
- 王芳的"更新用户画像文档"是上周会议(note_004)的遗留任务，仍在进行中
- agent应识别出这是未完成的遗留工作并在整理中提及

本部分评分标准：
- 0.9-1.0: 明确识别了遗留项，说明了它来自上周会议且仍未完成
- 0.4-0.8: 提到了用户画像相关内容但未明确标注为遗留/未完成
- 0.0-0.3: 完全没有提及遗留项

=== 第三部分：排除闲聊内容（权重20%）===
- 笔记中有闲聊内容（学Rust、爬山、花瓶、猫、才艺表演等）
- 好的整理应该只包含工作相关的行动项，不应把闲聊当作待办

本部分评分标准：
- 1.0: 完全没有将闲聊内容列为行动项或待办
- 0.5: 提到了闲聊内容但做了区分（如标注为"非工作相关"）
- 0.0: 将闲聊内容（学Rust、爬山等）作为正式行动项列出

请输出最终的加权分数：score = 0.6×第一部分 + 0.2×第二部分 + 0.2×第三部分
