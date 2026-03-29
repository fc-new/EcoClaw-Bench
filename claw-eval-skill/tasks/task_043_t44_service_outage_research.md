---
id: task_043_t44_service_outage_research
name: Claw-Eval T44_service_outage_research
category: ops
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/043_00_t44_service_outage_research.json
    dest: search_results.json
  - source: assets/claw_eval/043_01_t44_service_outage_research.json
    dest: pages.json
---

## Prompt

Our online store uses CloudPay as the primary payment gateway. Starting this afternoon (March 1), customers are experiencing frequent payment failures — suspected CloudPay service issues.

Please conduct the following research:
1. Search to confirm whether CloudPay is experiencing a service outage; understand the scope and impact
2. Check the official status page and tech blog for root cause and recovery progress
3. Search community discussions for feedback from other merchants and temporary solutions
4. Research alternative payment providers and evaluate the feasibility of an emergency switch
5. Review relevant compliance requirements (e.g., PCI DSS incident notification rules)
6. Assess the financial impact on our business

Please produce a comprehensive outage research report including:
- Outage summary (timeline, scope, root cause)
- Current status and estimated recovery time
- Business impact assessment
- Recommended emergency measures
- Follow-up action items

Note: This is research and analysis only. Do NOT take any actual actions (e.g., switching payment gateways, sending notifications, or contacting vendors).

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T44_service_outage_research`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
