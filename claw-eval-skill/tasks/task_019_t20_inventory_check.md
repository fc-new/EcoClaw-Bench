---
id: task_019_t20_inventory_check
name: Claw-Eval T20_inventory_check
category: operations
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/019_00_t20_inventory_check.json
    dest: products.json
---

## Prompt

Check which items are running low and place restock orders.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T20_inventory_check`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's analysis and decision-making quality in the inventory management task.
Score each of the three parts separately, then compute a weighted final score (0-1).

=== Part 1: Non-Obvious Low-Stock Identification (weight 25%) ===
SKU-009 (4K Monitor) is a non-obvious low-stock item:
- Current stock of 50 looks adequate
- But threshold is 100, daily sales 15, lead time 14 days
- Actually only 3.3 days of stock left, needs 210+ units reorder
- Agent should recognize "stock looks sufficient but actually below safety line"

SKU-010 (USB-C Hub) is a backordered item:
- Current stock 0, status backordered, ETA 2026-03-10 has passed
- Agent should specially flag its backordered status, not treat as simple stockout

Part 1 scoring:
- 0.9-1.0: Clearly noted SKU-009 looks adequate but is actually below safety line, and specially addressed SKU-010's backordered status and overdue ETA
- 0.6-0.8: Mentioned both as low-stock but didn't deeply analyze non-obvious features
- 0.3-0.5: Listed products but no special analysis
- 0.0-0.2: Missed SKU-009 or SKU-010

=== Part 2: Urgency Ranking (weight 40%) ===
Correct urgency order (by days of stock remaining):
1. SKU-004 (0 days, out of stock)
2. SKU-010 (0 days, backordered, ETA overdue)
3. SKU-001 (0.4 days)
4. SKU-008 (0.8 days)
5. SKU-006 (2.0 days)
6. SKU-003 (2.4 days)
7. SKU-009 (3.3 days)

Part 2 scoring:
- 0.9-1.0: Correctly ranked all 7 products by remaining days, top 3 most urgent correct
- 0.7-0.8: Top 3 most urgent basically correct, overall order roughly reasonable
- 0.5-0.6: Identified stockout items as most urgent but middle ranking wrong
- 0.3-0.4: Some ranking present but multiple errors
- 0.0-0.2: No urgency ranking

=== Part 3: Reorder Quantity Reasonableness (weight 35%) ===
Reasonable reorder ≈ daily_sales × lead_time + (threshold - current_stock):
- SKU-004: ≈30+15=45
- SKU-001: ≈56+17=73
- SKU-008: ≈30+15=45
- SKU-006: ≈28+17=45
- SKU-003: ≈25+18=43
- SKU-009: ≈210+50=260
- SKU-010: ≈56+20=76 (consider backordered status)

Part 3 scoring:
- 0.9-1.0: Suggested quantities within ±50% of reasonable values
- 0.7-0.8: Most quantities reasonable, a few significantly off
- 0.5-0.6: Gave quantities but most unreasonable (e.g., uniform 50 or too large)
- 0.3-0.4: Suggested restocking but no specific quantities
- 0.0-0.2: No orders placed or reorder quantities suggested

Output the final weighted score: score = 0.25×Part1 + 0.40×Part2 + 0.35×Part3
