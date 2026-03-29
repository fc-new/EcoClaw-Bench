---
id: task_022_t23zh_crm_data_export
name: Claw-Eval T23zh_crm_data_export
category: operations
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/022_00_t23zh_crm_data_export.json
    dest: customers.json
---

## Prompt

帮我从CRM系统导出一份VIP客户报告。需要：
1. 列出所有VIP客户
2. 获取每位VIP客户的详细信息
3. 生成一份包含所有VIP客户的汇总报告，包括客户名称、行业、年收入和最近联系日期
注意：系统最近不太稳定，如果遇到错误请重试。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T23zh_crm_data_export`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent生成的VIP客户报告质量。
请分别评估以下三个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：客户信息完整性（权重40%）===
报告应包含全部4位VIP客户，每位客户应有以下4个字段：
- 客户名称
- 行业分类
- 年收入
- 最近联系日期

参考数据：
- CUS-001 北京云创科技有限公司: 行业=科技, 收入=5,200,000, 最近联系=2026-02-20
- CUS-003 深圳智联电子科技有限公司: 行业=电子, 收入=8,900,000, 最近联系=2026-02-25
- CUS-005 成都天府软件园科技公司: 行业=科技, 收入=3,600,000, 最近联系=2026-02-27
- CUS-007 武汉光谷生物科技有限公司: 行业=生物科技, 收入=12,000,000, 最近联系=2026-02-26

本部分评分标准：
- 0.9-1.0: 全部4位客户均列出，且每位客户都有完整的4个字段
- 0.7-0.8: 4位客户均列出，但部分字段缺失
- 0.5-0.6: 列出了3位客户
- 0.3-0.4: 仅列出1-2位客户
- 0.0-0.2: 未列出VIP客户或报告为空

=== 第二部分：数据准确性（权重35%）===
检查报告中的具体数据是否与参考数据一致：
- 行业分类是否正确
- 收入数字是否正确（允许"万"等单位换算）
- 日期是否正确

本部分评分标准：
- 0.9-1.0: 所有数据字段准确无误
- 0.7-0.8: 大部分数据正确，1-2处小偏差
- 0.5-0.6: 约一半数据正确
- 0.3-0.4: 多数数据不准确
- 0.0-0.2: 数据严重错误或虚构

=== 第三部分：报告结构（权重25%）===
- 是否使用了表格或清晰的结构化格式
- 是否有标题和分区
- 是否有汇总信息（如总收入、行业分布等）
- 是否提到了错误恢复过程（任务涉及API不稳定）

本部分评分标准：
- 0.9-1.0: 完整的结构化报告（表格+标题+汇总+错误说明）
- 0.7-0.8: 有基本表格和结构
- 0.5-0.6: 简单列表形式
- 0.3-0.4: 纯文本叙述
- 0.0-0.2: 无结构

请输出最终的加权分数：score = 0.40×第一部分 + 0.35×第二部分 + 0.25×第三部分
