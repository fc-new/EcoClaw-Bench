---
id: task_028_t29zh_cross_service_meeting
name: Claw-Eval T29zh_cross_service_meeting
category: workflow
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/028_00_t29zh_cross_service_meeting.json
    dest: inbox.json
  - source: assets/claw_eval/028_01_t29zh_cross_service_meeting.json
    dest: contacts.json
  - source: assets/claw_eval/028_02_t29zh_cross_service_meeting.json
    dest: events.json
---

## Prompt

收件箱里有一封Partner Corp陈总监发来的项目评审会议邀请。
请帮我处理：
1. 阅读邮件了解会议需求
2. 查找赵磊和李明的联系方式
3. 查看他们周三（2026年3月4日）下午的日程安排
4. 找到所有人都有空的时段，安排一个2小时的会议
5. 给陈总监回复确认邮件，告知会议时间

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T29zh_cross_service_meeting`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent回复陈总监（director@partner-corp.com）确认项目评审会议的邮件质量。
正确的会议时间为3月4日（周三）15:00-17:00，参会人员包括赵磊、李明和陈总监团队。
请分别评估以下三个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：信息完整性（权重40%）===
回复邮件应包含所有关键会议信息：
- 确认日期和时间（3月4日，15:00-17:00）
- 会议时长（2小时）
- 参会人员（赵磊、李明和陈总监团队）
- 会议主题（项目评审）

本部分评分标准：
- 0.9-1.0: 所有信息完整准确
- 0.7-0.8: 时间确认但缺少1-2项信息
- 0.4-0.6: 时间正确但大部分信息缺失
- 0.0-0.3: 关键信息（时间/日期）错误或缺失

=== 第二部分：推理透明度（权重30%）===
回复是否解释了时间选择的原因：
- 是否提到赵磊14:00-15:00有事，所以选了15:00
- 是否说明所有参会者15:00-17:00都有空
- 是否提供了备选时间（如周四）以防陈总监不方便

本部分评分标准：
- 0.9-1.0: 清楚解释了时间选择推理过程
- 0.6-0.8: 说明了时间但推理简略
- 0.3-0.5: 提及了时间但无任何推理
- 0.0-0.2: 完全没有推理说明

=== 第三部分：专业性（权重30%）===
回复是否适合对外沟通：
- 语气礼貌专业（对方是合作伙伴公司总监）
- 结构清晰、格式得体
- 邮件主题合适

本部分评分标准：
- 0.9-1.0: 专业得体、措辞精炼
- 0.6-0.8: 基本专业但稍显随意
- 0.3-0.5: 信息传达到位但不够正式
- 0.0-0.2: 不专业或措辞不当

请输出最终的加权分数：score = 0.40×第一部分 + 0.30×第二部分 + 0.30×第三部分
