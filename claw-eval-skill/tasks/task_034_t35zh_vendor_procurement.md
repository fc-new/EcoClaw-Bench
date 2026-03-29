---
id: task_034_t35zh_vendor_procurement
name: Claw-Eval T35zh_vendor_procurement
category: procurement
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/034_00_t35zh_vendor_procurement.json
    dest: products.json
  - source: assets/claw_eval/034_01_t35zh_vendor_procurement.json
    dest: articles.json
  - source: assets/claw_eval/034_02_t35zh_vendor_procurement.json
    dest: customers.json
  - source: assets/claw_eval/034_03_t35zh_vendor_procurement.json
    dest: articles.json
  - source: assets/claw_eval/034_04_t35zh_vendor_procurement.json
    dest: transactions.json
---

## Prompt

我们需要采购一批服务器，帮我做一个供应商评估。请：
1. 查看库存系统了解当前服务器库存和需求
2. 检查RSS新闻了解各供应商的市场动态
3. 在CRM中查看各供应商的合作历史和状态
4. 查看知识库的采购政策和评估标准
5. 查看财务系统的预算和历史采购记录
6. 综合所有信息给出供应商评估报告和采购建议
注意：不要直接下采购单或联系供应商，只做评估分析。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T35zh_vendor_procurement`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent是否识别并分析了每个供应商的矛盾信号。

四个供应商的矛盾信号：
1. 华信达：获得"最佳服务商"奖项、VIP长期合作伙伴（正面）vs 10% DOA到货即损率（负面）
2. 博通信息：价格有竞争力（正面）vs 公司裁员导致售后支持能力不足（负面）
3. 联想：可靠性评测最高分（正面）vs 价格固定无折扣、灵活性不足（负面）
4. 新晨科技：价格便宜8%（正面）vs 华为供应链延迟3-6个月（负面）

核心考察：agent是否明确指出了每个供应商同时存在的正面和负面信号，并将它们作为"矛盾"来分析，而非只报告好消息或只报告坏消息。

评分标准：
- 0.9-1.0: 全部4个供应商的矛盾信号都被明确识别和分析
- 0.7-0.8: 3个供应商的矛盾被识别
- 0.5-0.6: 2个供应商的矛盾被识别
- 0.2-0.4: 仅1个供应商或只是分别列出优劣而未指出矛盾
- 0.0-0.1: 未识别任何矛盾信号

===RUBRIC===

评估agent是否按照KB-401采购政策的加权评分体系对供应商进行了结构化评估。

KB-401规定的评分权重：
- 价格(30%)、交付(25%)、质量(20%)、合作关系(15%)、售后支持(10%)

正确的评估应该：
1. 明确引用这些权重或类似的评分维度
2. 对每个供应商在各维度上进行评分或定性分析
3. 给出综合排名或推荐（基于加权结果）
4. 体现政策合规意识（如单一供应商不超过60%采购额）

评分标准：
- 0.9-1.0: 使用KB-401权重对全部4个供应商进行了多维度加权评估，有量化或半量化的比较
- 0.7-0.8: 引用了评分维度并评估了大部分供应商，但量化不够精确
- 0.4-0.6: 有评估但未使用标准权重，或维度不完整
- 0.1-0.3: 仅做了简单对比，无结构化评分
- 0.0: 完全没有评估框架

===RUBRIC===

评估agent是否正确分析了预算约束和审批流程。

关键事实：
1. Q1预算：200万元
2. 已有支出：约96.2万（68万 - 6.8万退款 + 35万）
3. 可用余额约103.8万，或以200万全额计算（取决于解读）
4. 全部补货需求估算约180万+（30台×8.5万 + 20台×7.8万 + 15台×7.2万）
5. 总额超过100万，按KB-401规定需要CEO审批
6. 预算可能不够一次性全部采购，需要分批/分期/优先排序

agent应该：
- 识别出预算与需求之间的缺口
- 指出需要CEO审批（超过100万阈值）
- 建议分阶段采购或优先采购紧急物资（如INV-303）

评分标准：
- 0.9-1.0: 准确计算了预算缺口，指出CEO审批要求，提出分阶段采购建议
- 0.6-0.8: 提到了预算限制和审批要求，但计算不够精确
- 0.3-0.5: 提到预算或审批其一，但分析不完整
- 0.0-0.2: 未提及预算约束或审批流程

===RUBRIC===

评估agent是否正确识别了库存需求。

库存状态：
- INV-301 (Dell PowerEdge R750): 低库存，需补货约30台，供应商华信达
- INV-302 (HP ProLiant DL380): 低库存，需补货约20台，供应商博通信息
- INV-303 (Huawei FusionServer): 严重缺货(critical)，需补货约15台，供应商新晨科技
- INV-304 (Lenovo ThinkSystem): 库存正常，无需补货
- INV-305 (网络设备): 低库存，需补货

agent应该：
- 区分低库存(low_stock)和严重缺货(critical)
- 明确INV-303是最紧急的补货需求
- 注意INV-304不需要补货
- 将库存需求与供应商评估关联起来

评分标准：
- 0.8-1.0: 识别了全部低库存项，正确区分了紧急程度，INV-303标记为最高优先级
- 0.5-0.7: 识别了大部分低库存项，但紧急程度区分不够明确
- 0.2-0.4: 只识别了部分库存问题
- 0.0-0.1: 未分析库存需求

===RUBRIC===

评估agent最终输出报告的综合质量。

一份好的供应商评估报告应包含：
1. 需求分析：明确需要采购什么、多少台、紧急程度
2. 供应商评估：每个供应商的优劣分析，包括矛盾信号
3. 加权评分：按采购政策的评分维度进行结构化对比
4. 预算分析：预算约束、审批要求
5. 推荐方案：分阶段采购建议、供应商分配策略
6. 风险提示：各供应商的主要风险

格式要求：结构化、有表格或对比矩阵、有清晰的结论和行动建议

评分标准：
- 0.8-1.0: 报告结构完整，覆盖以上大部分内容，格式专业清晰
- 0.5-0.7: 有基本结构，但部分内容缺失或深度不够
- 0.2-0.4: 内容零散，缺少关键部分
- 0.0-0.1: 不像一份正式的评估报告
