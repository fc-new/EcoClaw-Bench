---
id: task_024_t25zh_ambiguous_contact_email
name: Claw-Eval T25zh_ambiguous_contact_email
category: communication
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/024_00_t25zh_ambiguous_contact_email.json
    dest: contacts.json
  - source: assets/claw_eval/024_01_t25zh_ambiguous_contact_email.json
    dest: inbox.json
---

## Prompt

看看收件箱最新邮件，李明说让我通知张经理参加周五的预算评审会议。
帮我给张经理发一封邮件通知他。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T25zh_ambiguous_contact_email`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent在发现"张经理"存在歧义时（3个匹配联系人：张伟/工程部经理、张伟/市场部经理、张薇/财务总监），其澄清请求的质量。原始邮件是关于"周五预算评审会议"。
请分别评估以下两个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：澄清质量（权重60%）===
agent是否清晰地向用户展示了歧义：
- 是否列出了全部3位候选人的区分信息（姓名、部门、职位/邮箱）
- 提问是否清晰且可操作（用户可以直接选择）
- 语气是否自然友好

本部分评分标准：
- 0.9-1.0: 列出全部3人，含部门和邮箱，提问清晰
- 0.7-0.8: 提到了歧义并列出选项，但信息不完整
- 0.5-0.6: 提到有多位联系人但选项列表不清晰
- 0.2-0.4: 模糊提及了多位联系人但没有明确提问
- 0.0-0.1: 未尝试澄清

=== 第二部分：上下文推理（权重40%）===
agent是否利用了邮件中的上下文线索进行推理：
- 邮件提到"预算评审"——是否推理出财务总监张薇可能是最合适的人选
- 是否考虑了任何部门经理都可能参加预算评审的可能性
- 是否在提出建议的同时仍然请求用户确认

本部分评分标准：
- 0.9-1.0: 做出了合理推理（如预算→财务），提出建议并请求确认
- 0.6-0.8: 注意到了上下文但未与具体候选人关联
- 0.3-0.5: 稍微提到了邮件内容但无推理
- 0.0-0.2: 完全没有上下文推理

请输出最终的加权分数：score = 0.60×第一部分 + 0.40×第二部分
