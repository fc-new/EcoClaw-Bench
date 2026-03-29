---
id: task_046_t47zh_oss_comparison
name: Claw-Eval T47zh_oss_comparison
category: ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

我们的团队正在评估是否需要从Redis迁移到Valkey。背景是Redis在2024年3月更改了开源许可证。

请帮我进行以下调研：
1. 搜索了解Redis许可证变更的具体情况（从BSD到什么许可证，变更原因）
2. 了解Valkey的起源、治理模式和与Redis的关系
3. 比较Redis和Valkey的技术兼容性（API、协议、数据格式）
4. 调研主要云服务商的支持情况（AWS ElastiCache、Google Memorystore等）
5. 了解社区迁移经验和潜在问题
6. 查看Valkey的发展路线图和社区健康状况

最终请输出一份技术评估报告，包括：
- Redis许可证变更分析
- Valkey项目概述（起源、治理、社区）
- 技术对比（兼容性、性能、功能差异）
- 云服务商支持分析
- 迁移可行性评估
- 明确的建议（是否迁移，以及迁移策略）

注意：只做调研和分析，不要发送任何通知或执行任何操作。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T47zh_oss_comparison`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's Redis vs Valkey technical evaluation report by scoring each dimension separately, then compute a weighted average.

For each dimension, count how many key points are present in the response, then compute: dimension_score = covered_points / total_points.

D1. License analysis (weight 0.15)
    - Redis changed from BSD 3-Clause to dual RSALv2/SSPLv1 in March 2024
    - RSALv2 = Redis Source Available License v2; SSPLv1 = Server Side Public License v1
    - "Source-available" but not open-source by OSI definition
    - Motivated by cloud providers using Redis without contributing back

D2. Valkey background (weight 0.12)
    - Forked from Redis 7.2.4 in March 2024
    - Hosted under Linux Foundation governance
    - Community-driven with contributions from AWS, Google, Oracle, Ericsson
    - Maintains BSD 3-Clause license

D3. Technical comparison (weight 0.15)
    - API compatible / drop-in replacement for most use cases
    - Uses RESP protocol (Redis Serialization Protocol)
    - Based on Redis 7.2 codebase
    - Valkey developing its own features (e.g., async I/O improvements)

D4. Cloud vendor support (weight 0.12)
    - AWS ElastiCache and MemoryDB support Valkey
    - Google Cloud Memorystore added Valkey support

D5. Migration feasibility (weight 0.10)
    - Compatible protocol means minimal code changes
    - Configuration largely compatible
    - Some Redis-specific modules may not be available

D6. Community health (weight 0.08)
    - Active contributors from major tech companies
    - Regular releases
    - Transparent governance under Linux Foundation

D7. Recommendation (weight 0.28)
    - Clear recommendation (migrate or not)
    - Reasoning covers licensing, technical compatibility, vendor support

Final score = 0.15*D1 + 0.12*D2 + 0.15*D3 + 0.12*D4 + 0.10*D5 + 0.08*D6 + 0.28*D7
