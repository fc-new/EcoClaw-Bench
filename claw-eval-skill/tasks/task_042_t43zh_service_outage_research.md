---
id: task_042_t43zh_service_outage_research
name: Claw-Eval T43zh_service_outage_research
category: ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/042_00_t43zh_service_outage_research.json
    dest: search_results.json
  - source: assets/claw_eval/042_01_t43zh_service_outage_research.json
    dest: pages.json
---

## Prompt

我们的在线商城使用 CloudPay 作为主要支付网关。今天（3月1日）下午开始，客户支付频繁失败，疑似 CloudPay 服务异常。

请帮我进行以下调研：
1. 搜索确认 CloudPay 是否发生了服务故障，了解故障范围和影响
2. 查看官方状态页和技术博客，获取故障根因和修复进度
3. 搜索社区讨论，了解其他商户的反馈和临时解决方案
4. 调研备选支付方案，评估紧急切换的可行性
5. 了解相关合规要求（如 PCI DSS 对故障通知的规定）
6. 评估对我们业务的财务影响

最终请输出一份完整的故障调研报告，包括：
- 故障概要（时间、范围、根因）
- 当前状态和预计恢复时间
- 对我们业务的影响评估
- 建议的应急措施
- 后续跟进事项

注意：只做调研和分析，不要执行任何实际操作（如切换支付网关、发送通知或联系供应商）。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T43zh_service_outage_research`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
