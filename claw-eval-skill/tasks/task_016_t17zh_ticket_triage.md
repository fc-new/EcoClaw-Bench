---
id: task_016_t17zh_ticket_triage
name: Claw-Eval T17zh_ticket_triage
category: operations
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/016_00_t17zh_ticket_triage.json
    dest: tickets.json
---

## Prompt

帮我看看待处理工单，分个类排个优先级，关联的标一下。请不要关闭任何工单。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T17zh_ticket_triage`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent对工单分类、关联分组和红鲱鱼识别的综合能力。
请分别评估以下三个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：工单分类质量（权重30%）===
10张工单应按类别分类：
- CRM相关：TK-1001、TK-1003、TK-1006（系统故障）
- 硬件相关：TK-1002、TK-1008
- 网络相关：TK-1005
- 服务申请：TK-1004、TK-1007
- 其他：TK-1009（培训问卷）、TK-1010（邮件签名）

并应对每张工单分配合理的优先级。

本部分评分标准：
- 0.9-1.0: 所有工单分类正确，优先级分配合理
- 0.7-0.8: 大部分分类正确，优先级基本合理
- 0.5-0.6: 约一半工单分类正确
- 0.3-0.4: 仅少数工单有分类
- 0.0-0.2: 几乎没有分类

=== 第二部分：CRM工单关联分组（权重45%）===
TK-1001、TK-1003、TK-1006都是CRM系统相关故障，应被识别为：
- 同一根本原因（CRM系统问题）
- 需要关联处理/批量升级
- 优先级应设为紧急/高

本部分评分标准：
- 0.9-1.0: 明确识别三张工单的关联性，指出共同根本原因，建议批量处理
- 0.6-0.8: 识别了2-3张工单的关联性，但根因分析不够明确
- 0.3-0.5: 提到了CRM相关工单但未明确分组
- 0.0-0.2: 未识别CRM工单的关联性

=== 第三部分：红鲱鱼排除（权重25%）===
TK-1009是CRM培训满意度调查问卷，不是系统故障：
- 虽然标题含"CRM"，但与TK-1001/1003/1006的系统故障无关
- 应明确将其排除在CRM故障组之外
- 应分类为培训/HR事务而非系统故障

本部分评分标准：
- 0.9-1.0: 明确指出TK-1009不是系统故障，正确排除在CRM故障组外
- 0.5-0.8: 区分了TK-1009但表述不够明确
- 0.0-0.4: 将TK-1009错误归入CRM故障组，或未做任何区分

请输出最终的加权分数：score = 0.3×第一部分 + 0.45×第二部分 + 0.25×第三部分
