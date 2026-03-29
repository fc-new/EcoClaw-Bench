---
id: task_010_t11zh_expense_report
name: Claw-Eval T11zh_expense_report
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/010_00_t11zh_expense_report.json
    dest: transactions.json
---

## Prompt

帮我整理提交2026年2月的报销。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T11zh_expense_report`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent对13笔交易的分类准确度。

正确的分类：
- 餐饮：txn_001（咖啡）、txn_005（外卖）、txn_009（宴请）
- 差旅：txn_002（打车）、txn_003（打车）、txn_006（机票）、txn_007（酒店）、txn_011（打车）
- IT设备：txn_004（键盘）、txn_013（显示器）
- 办公：txn_008（文具）
- 云服务：txn_010（服务器）
- 退款：txn_012（退款，负金额）

评分标准：
- 0.9-1.0: 全部或绝大部分交易分类正确，分类体系合理
- 0.7-0.8: 大部分分类正确，个别有误或分类维度略有不同但合理
- 0.4-0.6: 部分分类正确但有较多错误或遗漏
- 0.1-0.3: 仅少量分类正确或分类混乱
- 0.0: 完全没有分类

===RUBRIC===

评估agent识别和处理异常交易的能力。

三类异常交易需要识别：

1. 完全重复：txn_002和txn_003
   - 同一日期、同一商家（滴滴出行）、同一金额（45元）
   - 应标记为重复，提交时排除其一

2. 近似重复：txn_011
   - 与txn_002/003类似（也是滴滴出行、也是打车），但金额为44.99（差0.01元）
   - 应指出差异，可能是返程的正常交易，不应自动合并

3. 退款交易：txn_012
   - 金额为-328元（负数）
   - 应识别为退款/冲抵，而非普通消费

评分标准：
- 0.9-1.0: 三类异常全部正确识别并恰当处理
- 0.7-0.8: 识别了重复和退款，但近似重复处理不够清晰
- 0.4-0.6: 只识别了一两类异常
- 0.1-0.3: 仅简单提及，没有实质性分析
- 0.0: 未识别任何异常交易
