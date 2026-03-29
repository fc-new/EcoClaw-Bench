---
id: task_014_t15zh_kb_search
name: Claw-Eval T15zh_kb_search
category: knowledge
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/014_00_t15zh_kb_search.json
    dest: articles.json
---

## Prompt

VPN连不上，帮我查查知识库怎么解决。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T15zh_kb_search`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent从多篇知识库文章中综合信息和发现矛盾的能力。
请分别评估以下两个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：信息综合质量（权重50%）===
agent应从多篇文章中综合VPN问题排查的关键信息：
- FortiClient/GlobalProtect VPN客户端的使用方法
- MFA多因素认证的要求
- 密码/账号相关的排查步骤
- 防火墙/网络配置相关信息
- vpn.company.com连接地址
- 企业微信等辅助工具

本部分评分标准：
- 0.9-1.0: 综合了5个以上关键信息点，形成完整的VPN排查清单
- 0.7-0.8: 综合了3-4个关键信息点，基本覆盖主要排查步骤
- 0.5-0.6: 综合了2-3个信息点，但遗漏了重要内容
- 0.3-0.4: 仅提及1-2个信息点，综合不足
- 0.0-0.2: 几乎没有综合多篇文章的信息

=== 第二部分：矛盾信息识别（权重50%）===
知识库中存在关键矛盾：
- kb_001推荐使用FortiClient作为VPN客户端
- kb_006通知FortiClient将被GlobalProtect替代（迁移中）
- agent应明确指出这一矛盾/更新，建议用户使用GlobalProtect而非FortiClient

本部分评分标准：
- 0.9-1.0: 明确识别了FortiClient→GlobalProtect的迁移/替换，给出了正确建议
- 0.7-0.8: 提到了两种客户端，暗示有变更但未明确说明矛盾
- 0.4-0.6: 仅列出了两种客户端名称，未分析矛盾关系
- 0.1-0.3: 只提到一种客户端，未发现矛盾
- 0.0: 完全没有涉及VPN客户端的信息

请输出最终的加权分数：score = 0.5×第一部分 + 0.5×第二部分
