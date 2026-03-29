---
id: task_049_t50_regulatory_research
name: Claw-Eval T50_regulatory_research
category: compliance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Our company is developing an AI customer service system for the European market. We need to research the EU AI Act compliance requirements.

Please conduct the following research:
1. Search for and understand the EU AI Act framework and legislative status
2. Study the AI risk classification system (unacceptable, high, limited, minimal risk)
3. Determine which risk tier an AI customer service chatbot falls into and its specific compliance obligations
4. Understand the compliance timeline (effective dates for each phase)
5. Research the penalty structure (fine amounts and calculation methods)
6. Review technical compliance requirements (transparency, human oversight, data governance)
7. Search for enterprise compliance practices and preparation advice

Please produce a comprehensive compliance assessment report including:
- EU AI Act framework overview
- Risk classification system explained
- AI chatbot compliance classification and requirements
- Key timeline milestones and compliance deadlines
- Penalty details
- Technical compliance requirement checklist
- Recommended compliance action roadmap

Note: This is research and analysis only. Do NOT send any notifications or take any actions.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T50_regulatory_research`

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
