---
id: task_052_t53_finance_us_steel_merger
name: Claw-Eval T53_finance_us_steel_merger
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

How has US Steel addressed its planned merger with Nippon Steel and its effect on its business operations?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T53_finance_us_steel_merger`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent accurately explained how US Steel addressed its planned merger with Nippon Steel.

Key facts the response should contain:
- Companies: U.S. Steel and Nippon Steel
- Announcement date: December 18, 2023
- Strategic framing: presented as a strategic partnership for long-term survival
- CEO: David B. Burritt highlighted competitiveness benefits
- Stakeholder safeguards: U.S. government golden share / national-interest protection
- Jobs commitment: safeguarding 100,000+ jobs, especially in Western Pennsylvania
- Capital plan: total pledge ~$14B, including ~$11B by 2028; up to $4B for a U.S. advanced mill
- Operational impact: expected modernization gains — lower costs/downtime, reduced emissions, higher productivity, stronger supply-chain resilience

Scoring guidance:
- 0.90-1.00: Covers nearly all key facts accurately and ties them to business impact.
- 0.70-0.89: Covers most key facts with minor omissions.
- 0.40-0.69: Partial coverage; misses several key facts or weak causal explanation.
- 0.00-0.39: Major factual gaps or contradictory claims.
