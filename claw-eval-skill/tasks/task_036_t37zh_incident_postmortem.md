---
id: task_036_t37zh_incident_postmortem
name: Claw-Eval T37zh_incident_postmortem
category: ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/036_00_t37zh_incident_postmortem.json
    dest: tickets.json
  - source: assets/claw_eval/036_01_t37zh_incident_postmortem.json
    dest: integrations.json
  - source: assets/claw_eval/036_02_t37zh_incident_postmortem.json
    dest: inbox.json
  - source: assets/claw_eval/036_03_t37zh_incident_postmortem.json
    dest: articles.json
  - source: assets/claw_eval/036_04_t37zh_incident_postmortem.json
    dest: meetings.json
  - source: assets/claw_eval/036_05_t37zh_incident_postmortem.json
    dest: jobs.json
---

## Prompt

昨晚（2月28日）生产环境发生了一次重大故障。请帮我做一份事故复盘分析报告：
1. 收集所有相关工单建立故障时间线
2. 查看系统集成状态了解当前恢复情况
3. 查看相关邮件了解技术细节
4. 检查知识库是否有类似历史事故
5. 查看会议记录了解近期变更
6. 检查定时任务了解触发情况
注意：这是只读分析，不要修改、关闭、通知或更新任何内容。只做数据收集和根因分析。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T37zh_incident_postmortem`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent是否正确识别了事故的根本原因。

真正的根本原因（必须全部识别才算完整）：
1. CRM数据同步定时任务(crm_data_sync / JOB-301)在20:00自动执行
2. 该任务中包含一个未优化的SQL查询（全表扫描，未走索引）
3. 这个SQL查询是上周五(2月27日)发版时引入的新代码
4. 该SQL大量消耗数据库连接，导致连接池耗尽(200/200)
5. 连接池耗尽后导致级联故障：API超时、支付503、订单失败、任务队列堆积

核心区分：agent必须识别出是CRM同步任务的SQL问题（根因），而不仅仅是报告"数据库连接池耗尽"（症状）。

评分标准：
- 0.9-1.0: 准确指出CRM同步任务的SQL全表扫描是根因，关联了TK-1908和/或JOB-301的证据
- 0.7-0.8: 识别了CRM同步是问题源头，但SQL细节不完整
- 0.4-0.6: 识别了数据库连接池问题，但没有追溯到CRM同步任务的SQL
- 0.1-0.3: 仅描述了症状（支付失败、超时等），未找到根因
- 0.0: 完全没有根因分析

===RUBRIC===

评估agent是否构建了完整的因果链。

正确的因果链（4个环节）：
1. 触发：20:00定时任务(JOB-301/crm_data_sync)自动启动
2. 根因：执行了未优化的SQL（全表扫描，新代码引入，未经DBA评审）
3. 直接影响：SQL占用大量数据库连接 → 连接池耗尽(200/200)
4. 级联故障：API超时 → 支付服务503 → 约200笔订单失败 → Celery任务队列堆积5万条

恢复过程：DBA在21:30手动kill了CRM同步进程 → 21:35各服务恢复

核心考察：agent是否将这些事件串联成一条因果链，而非孤立地列出各个症状。

评分标准：
- 0.9-1.0: 完整呈现了4个环节的因果链，逻辑清晰，有恢复过程描述
- 0.7-0.8: 因果链基本完整，但某个环节描述不够清晰
- 0.4-0.6: 提到了大部分事件，但因果关系不够明确
- 0.1-0.3: 仅列出了部分症状，缺乏因果串联
- 0.0: 没有因果分析

===RUBRIC===

评估agent对事故影响的评估以及流程缺陷的识别。

事故影响（应该覆盖）：
- 支付服务返回503错误
- 约200笔订单处理失败
- 用户投诉增加，客服工单激增
- Celery任务队列堆积约5万条
- 服务中断时间约75分钟（20:15 ~ 21:35）

流程缺陷（应该识别）：
1. CRM同步的SQL变更跳过了DBA性能评审
2. DBA在发版评审会上提出了性能测试的建议但被否决（时间紧迫）
3. 上周五发版引入了未经充分测试的代码
4. 这与12月的事故(KB-603)是同一类问题，说明是系统性的流程缺陷

评分标准：
- 0.8-1.0: 影响评估全面且有数据支撑，流程缺陷分析深入（识别了评审跳过+DBA建议被否决+系统性问题）
- 0.5-0.7: 影响和流程缺陷都有涉及，但不够全面
- 0.2-0.4: 仅提到部分影响或流程问题
- 0.0-0.1: 未评估影响或未识别流程缺陷

===RUBRIC===

评估agent是否关联了历史事故并提出了有效的改进建议。

历史事故关联：
- KB-603记录了2025年12月的类似事故
- 当时的改进措施中有"CRM迁移到读副本"的TODO，但至今未实施
- 这次事故本质上是同一问题的重复发生，说明改进措施未落地

应提出的改进建议：
1. 为CRM同步SQL添加索引（立即止血）
2. 推进CRM读副本迁移（根治方案，来自KB-603 TODO）
3. 设置数据库连接数限制/隔离（防止单任务耗尽全局连接池）
4. 强制DBA性能评审流程（流程改进，杜绝未经评审的SQL上线）

评分标准：
- 0.8-1.0: 引用了KB-603历史事故，指出了未完成的TODO，提出了4类改进建议中至少3类
- 0.5-0.7: 提到了历史事故或提出了部分改进建议，但不够完整
- 0.2-0.4: 有少量改进建议但缺乏历史关联
- 0.0-0.1: 无改进建议或完全未提及历史

===RUBRIC===

评估agent输出的事后分析报告的结构和专业性。

一份好的事故复盘报告应包含：
1. 事故概述：简要描述发生了什么
2. 时间线：按时间顺序列出关键事件（使用具体时间戳和工单编号）
3. 根因分析：明确的根本原因而非症状
4. 因果链：从触发到影响的完整逻辑链
5. 影响范围：量化的业务影响
6. 流程分析：为什么会发生，流程上的缺陷
7. 改进建议：短期和长期的改进措施

格式要求：结构化呈现，有清晰的章节划分，时间线使用时间戳

评分标准：
- 0.8-1.0: 包含以上大部分章节，格式专业，逻辑清晰，有时间线
- 0.5-0.7: 有基本结构但部分章节缺失
- 0.2-0.4: 内容零散，缺少关键章节
- 0.0-0.1: 不像一份正式的事故复盘报告
