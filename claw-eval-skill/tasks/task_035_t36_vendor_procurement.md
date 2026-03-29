---
id: task_035_t36_vendor_procurement
name: Claw-Eval T36_vendor_procurement
category: procurement
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/035_00_t36_vendor_procurement.json
    dest: products.json
  - source: assets/claw_eval/035_01_t36_vendor_procurement.json
    dest: articles.json
  - source: assets/claw_eval/035_02_t36_vendor_procurement.json
    dest: customers.json
  - source: assets/claw_eval/035_03_t36_vendor_procurement.json
    dest: articles.json
  - source: assets/claw_eval/035_04_t36_vendor_procurement.json
    dest: transactions.json
---

## Prompt

We need to procure a batch of servers. Help me do a vendor evaluation. Please:
1. Check the inventory system for current server stock and needs
2. Check RSS news for vendor market developments
3. Look up vendor partnership history in the CRM
4. Review procurement policy and evaluation criteria in the knowledge base
5. Check the finance system for budget and historical procurement records
6. Synthesize all information into a vendor evaluation report with procurement recommendations
Note: Do not place any purchase orders or contact vendors directly — only evaluate and analyze.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T36_vendor_procurement`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate whether the agent identified and analyzed the contradictory signals for each vendor.

Four vendors' contradictory signals:
1. Huaxinda: Won "Best Vendor" award, VIP long-term partner (positive) vs 10% DOA (dead on arrival) rate (negative)
2. Botong: Competitive pricing (positive) vs company layoffs affecting after-sales support capacity (negative)
3. Lenovo: Highest reliability benchmark scores (positive) vs fixed pricing with no discounts, inflexible (negative)
4. Xinchen: 8% cheaper pricing (positive) vs Huawei supply chain delays of 3-6 months (negative)

Core test: Did the agent explicitly identify both positive and negative signals for each vendor and analyze them as "contradictions", rather than only reporting good news or bad news?

Scoring:
- 0.9-1.0: All 4 vendors' contradictions explicitly identified and analyzed
- 0.7-0.8: 3 vendors' contradictions identified
- 0.5-0.6: 2 vendors' contradictions identified
- 0.2-0.4: Only 1 vendor, or listed pros/cons without highlighting contradictions
- 0.0-0.1: No contradictory signals identified

===RUBRIC===

Evaluate whether the agent applied the KB-401 procurement policy's weighted scoring framework for structured vendor evaluation.

KB-401 scoring weights:
- Price (30%), Delivery (25%), Quality (20%), Relationship (15%), Support (10%)

Correct evaluation should:
1. Explicitly reference these weights or similar scoring dimensions
2. Score or qualitatively analyze each vendor on each dimension
3. Provide an overall ranking or recommendation based on weighted results
4. Show policy compliance awareness (e.g., single-supplier cap of 60%)

Scoring:
- 0.9-1.0: Used KB-401 weights to evaluate all 4 vendors with quantitative or semi-quantitative comparison
- 0.7-0.8: Referenced scoring dimensions and evaluated most vendors, but quantification not precise
- 0.4-0.6: Some evaluation but didn't use standard weights or incomplete dimensions
- 0.1-0.3: Only simple comparison, no structured scoring
- 0.0: No evaluation framework at all

===RUBRIC===

Evaluate whether the agent correctly analyzed budget constraints and approval requirements.

Key facts:
1. Q1 budget: 2 million CNY
2. Prior spending: ~962K (680K - 68K refund + 350K)
3. Available balance: ~1.038M, or full 2M depending on interpretation
4. Full reorder estimate: ~1.8M+ (30x85K + 20x78K + 15x72K)
5. Total exceeds 1 million threshold — requires CEO approval per KB-401
6. Budget may not cover full procurement — needs phased/prioritized approach

The agent should:
- Identify the gap between budget and needs
- Note the CEO approval requirement (over 1 million threshold)
- Suggest phased procurement or prioritizing critical items (e.g., INV-303)

Scoring:
- 0.9-1.0: Accurately calculated budget gap, noted CEO approval, proposed phased procurement
- 0.6-0.8: Mentioned budget limits and approval but calculations imprecise
- 0.3-0.5: Mentioned only budget or approval, incomplete analysis
- 0.0-0.2: Did not address budget constraints or approval process

===RUBRIC===

Evaluate whether the agent correctly identified inventory needs.

Inventory status:
- INV-301 (Dell PowerEdge R750): low stock, need ~30 units, supplier Huaxinda
- INV-302 (HP ProLiant DL380): low stock, need ~20 units, supplier Botong
- INV-303 (Huawei FusionServer): critical shortage, need ~15 units, supplier Xinchen
- INV-304 (Lenovo ThinkSystem): normal stock, no reorder needed
- INV-305 (network equipment): low stock, needs reorder

The agent should:
- Distinguish low_stock from critical
- Flag INV-303 as highest priority
- Note INV-304 doesn't need reordering
- Link inventory needs to vendor evaluation

Scoring:
- 0.8-1.0: Identified all low-stock items, correctly differentiated urgency, INV-303 marked highest priority
- 0.5-0.7: Identified most low-stock items but urgency differentiation unclear
- 0.2-0.4: Only identified some inventory issues
- 0.0-0.1: Did not analyze inventory needs

===RUBRIC===

Evaluate the overall quality of the agent's final evaluation report.

A good vendor evaluation report should contain:
1. Needs analysis: what to procure, quantities, urgency levels
2. Vendor evaluation: pros/cons for each vendor including contradictory signals
3. Weighted scoring: structured comparison using procurement policy dimensions
4. Budget analysis: constraints and approval requirements
5. Recommendation: phased procurement strategy, vendor allocation
6. Risk assessment: key risks per vendor

Format: structured with tables or comparison matrices, clear conclusions and action items

Scoring:
- 0.8-1.0: Complete structure covering most areas above, professional format
- 0.5-0.7: Basic structure but some content missing or shallow
- 0.2-0.4: Scattered content, missing key sections
- 0.0-0.1: Does not resemble a formal evaluation report
