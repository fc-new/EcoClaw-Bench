---
id: task_068_t69_micron_capex_analysis
name: Claw-Eval T69_micron_capex_analysis
category: finance
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

The semiconductor industry is typically capital-intensive. In its FY2025 earnings report, Micron management disclosed that to support HBM (High Bandwidth Memory) and future technology nodes, the company's capital expenditures for FY2025 reached a very high level and will rise further in FY2026.
Investors are concerned: Will high capital expenditures deplete the company's cash flow? Historically, memory chip manufacturers have often triggered subsequent price collapses and liquidity crunches due to excessive capacity expansion at the peak of a cycle. As a financial analyst, you are required to assess whether Micron's current cash flow generation capability is sufficient to sustain this capital expenditure cycle and determine whether its expansion strategy is rational.

Analysis Task: Based on Micron Technology's FY2025 (full year) Statement of Cash Flows data, please complete the following analyses:

1. Free Cash Flow (FCF) and Coverage Ratio Calculation: Using operating cash flow and net capital expenditures, calculate Adjusted Free Cash Flow for FY2025. Simultaneously, calculate the Capital Expenditure Coverage Ratio (i.e., the ratio of capital expenditures to Adjusted Free Cash Flow) to evaluate the company's ability to cover investment requirements solely through its internal cash generation.

2. FY2026 Breakeven Scenario Simulation: Assuming FY2026 capital expenditures reach $20 billion as indicated in guidance, and the company's Operating Cash Flow Margin (i.e., OCF/Revenue) remains at the FY2025 level of 47%, calculate the revenue level Micron must achieve in FY2026 to maintain non-negative Free Cash Flow (i.e., FCF >= 0).

3. Structural Analysis of Capital Expenditures: Contrasting with historical instances of blind expansion, analyze the structural characteristics of Micron's current round of capital expenditures. Specifically, incorporating information regarding the "10% reduction in NAND wafer capacity" and "investment in HBM back-end packaging equipment," demonstrate why management claims to have maintained "capacity discipline" despite the massive expenditures.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T69_micron_capex_analysis`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the Micron FY2025 CapEx analysis report against the following rubric:

POSITIVE SCORING ITEMS (total 100%):
1. [Weight 13%] FY2025 Operating Cash Flow of $17.5 billion — accurate data extraction
2. [Weight 13%] FY2025 Net Capital Expenditure of $13.8 billion — accurate data extraction
3. [Weight 10%] Calculated FY2025 Adjusted Free Cash Flow of $3.7 billion ($17.5B - $13.8B)
4. [Weight 10%] Capital Expenditure Coverage Ratio of 1.27 ($17.5B / $13.8B) — correct calculation
5. [Weight 10%] FY2026 breakeven revenue of approximately $42.6 billion ($20B / 0.47) — correct calculation
6. [Weight 9%] NAND capacity reduction of 10% — demonstrates capacity discipline
7. [Weight 9%] Equipment reallocation from NAND to DRAM production
8. [Weight 6%] Significant CapEx allocation to HBM back-end packaging equipment
9. [Weight 6%] New wafer fabrication plants in Idaho and New York
10. [Weight 7%] Analysis that new plant construction has long lead times, delaying capacity release until post-2027
11. [Weight 7%] Structural argument: CapEx is for technology migration and packaging, not raw wafer capacity expansion

NEGATIVE SCORING ITEMS (deduct when present):
12. [Deduct 6%] Excessive background information not relevant to the specific analysis tasks
13. [Deduct 4%] Missing currency units (USD) or inconsistent unit usage (millions vs billions mixing)
14. [Deduct 4%] Contradictory assumptions within the analysis
15. [Deduct 4%] Emotive or non-neutral language (e.g., "skyrocketing," "devastating")
16. [Deduct 4%] Incorrect mathematical calculations

Response should be structured around the three analysis tasks: FCF calculation, breakeven simulation, structural analysis.
