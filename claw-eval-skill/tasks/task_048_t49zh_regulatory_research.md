---
id: task_048_t49zh_regulatory_research
name: Claw-Eval T49zh_regulatory_research
category: compliance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

我们公司正在为欧洲市场开发AI客服系统。需要你调研欧盟AI法案的相关合规要求。

请完成以下调研：
1. 搜索了解欧盟AI法案（EU AI Act）的整体框架和立法状态
2. 研究AI系统的风险分类体系（不可接受风险、高风险、有限风险、最小风险）
3. 确定AI客服聊天机器人属于哪个风险等级，及其具体合规义务
4. 了解合规时间线（各阶段生效日期）
5. 研究违规处罚力度（罚款金额和计算方式）
6. 了解技术层面的合规要求（透明度、人工监督、数据治理等）
7. 搜索企业合规实践和准备建议

最终请输出一份合规评估报告，包括：
- EU AI Act整体框架概述
- 风险分类体系详解
- AI聊天机器人的合规定位和要求
- 关键时间节点和合规期限
- 违规处罚详情
- 技术合规要求清单
- 建议的合规行动路线图

注意：只做调研和分析，不要发送任何通知或执行任何操作。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T49zh_regulatory_research`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's EU AI Act compliance report by scoring each dimension separately, then compute a weighted average.

For each dimension, count how many key points are present in the response, then compute: dimension_score = covered_points / total_points.


D1. Framework overview (weight 0.12)
    - EU AI Act / Regulation (EU) 2024/1689
    - Risk-based approach
    - Entered into force August 1, 2024

D2. Risk classification (weight 0.20)
    - Unacceptable risk: banned (social scoring, biometric ID)
    - High risk: strict requirements (infrastructure, education, employment)
    - Limited risk: transparency obligations (chatbots, deepfakes)
    - Minimal risk: no obligations (spam filters, games)

D3. Chatbot classification (weight 0.17)
    - AI chatbots = limited risk
    - Must disclose to users they are interacting with AI
    - Transparency / user disclosure as primary obligation

D4. Compliance timeline (weight 0.12)
    - August 1, 2024: entered into force
    - February 2, 2025: prohibitions apply
    - August 2, 2025: GPAI rules apply
    - August 2, 2026: full application

D5. Penalties (weight 0.10)
    - Up to €35M or 7% turnover (unacceptable risk)
    - Up to €15M or 3% turnover (other violations)

D6. Technical requirements (weight 0.12)
    - Transparency, human oversight, data governance, record-keeping

D7. Compliance roadmap (weight 0.17)
    - Gap analysis, action items, prioritized by deadlines

Final score = 0.12*D1 + 0.20*D2 + 0.17*D3 + 0.12*D4 + 0.10*D5 + 0.12*D6 + 0.17*D7
