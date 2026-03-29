---
id: task_047_t48_oss_comparison
name: Claw-Eval T48_oss_comparison
category: ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Our team is evaluating whether to migrate from Redis to Valkey. This is prompted by Redis's license change in March 2024.

Please conduct the following research:
1. Search for and understand the Redis license change details (from BSD to what license, reasons behind the change)
2. Research Valkey's origin, governance model, and relationship to Redis
3. Compare Redis and Valkey technical compatibility (API, protocol, data format)
4. Investigate major cloud provider support (AWS ElastiCache, Google Memorystore, etc.)
5. Gather community migration experiences and potential issues
6. Review Valkey's development roadmap and community health

Please produce a comprehensive technical evaluation report including:
- Redis license change analysis
- Valkey project overview (origin, governance, community)
- Technical comparison (compatibility, performance, feature differences)
- Cloud vendor support analysis
- Migration feasibility assessment
- Clear recommendation (whether to migrate and migration strategy)

Note: This is research and analysis only. Do NOT send any notifications or take any actions.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T48_oss_comparison`

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
