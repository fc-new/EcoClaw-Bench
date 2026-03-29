---
id: task_004_t05zh_email_reply_draft
name: Claw-Eval T05zh_email_reply_draft
category: communication
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/004_00_t05zh_email_reply_draft.json
    dest: inbox.json
---

## Prompt

看看收件箱有什么重要邮件要回的，帮我起草好存草稿就行。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T05zh_email_reply_draft`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent给客户(client@bigcorp.com)起草的回复草稿质量。

背景：客户(刘总/大企业)发邮件询问项目延期问题，agent需要起草一封专业的回复。

好的客户回复草稿应包含：
1. 承认项目延期/进度问题
2. 提供具体的应对措施或加快方案
3. 涉及关键实体（客户名称/公司、项目相关信息）
4. 语气专业、有诚意，体现客户关怀
5. 提及相关的时间节点或交付日期

评分标准：
- 0.9-1.0: 草稿专业完整，涵盖了延期说明、应对措施、时间承诺，语气得体
- 0.7-0.8: 草稿涵盖了主要内容但某方面不够完整
- 0.4-0.6: 草稿过于简单，缺少具体措施或时间信息
- 0.1-0.3: 有草稿但内容几乎无实质意义
- 0.0: 没有给客户起草回复

===RUBRIC===

评估agent是否识别了邮件线程关系并在回复中体现了线程意识。

关键线程信息：
- msg_104是msg_101的后续跟进（同一客户client@bigcorp.com，同一话题：项目延期）
- msg_104体现了客户的紧迫感（等了一天没收到回复，管理层在追问）
- 好的回复应该体现对这条线程上下文的理解

线程意识的表现：
1. 在草稿中体现对客户多次来信的了解（如"关于您之前提到的…"）
2. 使用reply_to_message_id字段关联原始邮件
3. 回复中体现了对客户紧急程度的感知
4. 将两封邮件(msg_101和msg_104)作为同一问题处理

评分标准：
- 0.9-1.0: 明确识别了线程关系，回复中体现了对多次来信和紧急程度的理解
- 0.6-0.8: 识别了线程但体现不够充分
- 0.3-0.5: 有一些线程意识的迹象但不明确
- 0.0-0.2: 完全没有线程意识，将每封邮件视为独立的

===RUBRIC===

评估agent给老板(boss@company.com)起草的回复草稿质量。

背景：老板转发了一份竞品分析报告(msg_105)，涉及竞品产品A的定价分析。agent需要起草一封合适的回复。

好的老板回复草稿应包含：
1. 提及竞品分析/报告的核心内容
2. 体现对报告的理解或初步意见
3. 语气适合上下级沟通

评分标准：
- 0.9-1.0: 草稿内容与竞品分析报告高度相关，有实质性回应
- 0.6-0.8: 提到了报告但回应不够深入
- 0.3-0.5: 提到了老板但与报告内容关联不大
- 0.0-0.2: 没有给老板起草回复或内容完全无关
