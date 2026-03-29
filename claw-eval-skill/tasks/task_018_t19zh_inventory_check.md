---
id: task_018_t19zh_inventory_check
name: Claw-Eval T19zh_inventory_check
category: operations
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/018_00_t19zh_inventory_check.json
    dest: products.json
---

## Prompt

看看库存哪些要补货了，帮我下单。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T19zh_inventory_check`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent在库存管理任务中的分析和决策质量。
请分别评估以下三个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：非显性低库存识别（权重25%）===
SKU-009（4K显示器）是一个"不显眼"的低库存商品：
- 当前库存50台看起来很多
- 但阈值100台、日销15台、补货周期14天
- 实际只够3.3天，需要补货210+台
- agent应该能识别到"库存看似充足但实际低于安全线"

SKU-010（Type-C扩展坞）是已缺货的预订商品：
- 当前库存0，状态为backordered，预计到货日2026-03-10已过
- agent应特别标注该商品的特殊状态，而不是简单当作缺货处理

本部分评分标准：
- 0.9-1.0: 明确指出SKU-009看似充足但实际低于安全线，且特别说明SKU-010的backordered状态和ETA
- 0.6-0.8: 提到了两者均为低库存，但未深入分析非显性特征
- 0.3-0.5: 仅列出了产品名但未做特殊分析
- 0.0-0.2: 遗漏了SKU-009或SKU-010

=== 第二部分：紧急程度排序（权重40%）===
正确的紧急排序（按剩余天数）：
1. SKU-004（0天，已断货）
2. SKU-010（0天，backordered，ETA已过期）
3. SKU-001（0.4天）
4. SKU-008（0.8天）
5. SKU-006（2.0天）
6. SKU-003（2.4天）
7. SKU-009（3.3天）

本部分评分标准：
- 0.9-1.0: 按剩余天数正确排序全部7个产品，前3最紧急的完全正确
- 0.7-0.8: 前3最紧急的基本正确，整体排序大致合理
- 0.5-0.6: 识别出断货产品最紧急，但中间排序有误
- 0.3-0.4: 有一定排序但多处错误
- 0.0-0.2: 没有紧急程度排序

=== 第三部分：补货数量合理性（权重35%）===
合理补货量约等于 daily_sales × lead_time + (threshold - current_stock)：
- SKU-004: ≈30+15=45
- SKU-001: ≈56+17=73
- SKU-008: ≈30+15=45
- SKU-006: ≈28+17=45
- SKU-003: ≈25+18=43
- SKU-009: ≈210+50=260
- SKU-010: ≈56+20=76（需考虑backordered状态）

本部分评分标准：
- 0.9-1.0: 建议的补货量在合理范围的±50%内
- 0.7-0.8: 大部分数量合理，个别偏差较大
- 0.5-0.6: 给出了数量但多数不够合理（如统一下50或过大）
- 0.3-0.4: 建议了补货但没有给具体数量
- 0.0-0.2: 没有下单或建议补货量

请输出最终的加权分数：score = 0.25×第一部分 + 0.40×第二部分 + 0.35×第三部分
