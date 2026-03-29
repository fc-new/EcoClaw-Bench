---
id: task_015_t16_kb_search
name: Claw-Eval T16_kb_search
category: knowledge
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/015_00_t16_kb_search.json
    dest: articles.json
---

## Prompt

My VPN won't connect — search the knowledge base for a fix.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T16_kb_search`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's ability to synthesize information from multiple KB articles and detect contradictions.
Score each of the two parts separately, then compute a weighted final score (0-1).

=== Part 1: Information Synthesis Quality (weight 50%) ===
The agent should synthesize key VPN troubleshooting information from multiple articles:
- FortiClient/GlobalProtect VPN client usage
- MFA (multi-factor authentication) requirements
- Password/account troubleshooting steps
- Firewall/network configuration details
- vpn.company.com connection address
- Auxiliary tools (e.g., enterprise messaging)

Part 1 scoring:
- 0.9-1.0: Synthesized 5+ key information points into a comprehensive VPN checklist
- 0.7-0.8: Synthesized 3-4 key points, covering main troubleshooting steps
- 0.5-0.6: Synthesized 2-3 points but missed important content
- 0.3-0.4: Only mentioned 1-2 points, insufficient synthesis
- 0.0-0.2: Almost no multi-article synthesis

=== Part 2: Contradiction Detection (weight 50%) ===
The KB contains a key contradiction:
- kb_001 recommends FortiClient as the VPN client
- kb_006 announces FortiClient is being replaced by GlobalProtect (migration in progress)
- The agent should explicitly identify this contradiction/update and recommend GlobalProtect over FortiClient

Part 2 scoring:
- 0.9-1.0: Clearly identified the FortiClient→GlobalProtect migration, gave correct advice
- 0.7-0.8: Mentioned both clients, implied a change but didn't explicitly flag contradiction
- 0.4-0.6: Listed both client names but didn't analyze the contradiction
- 0.1-0.3: Only mentioned one client, didn't discover the contradiction
- 0.0: No VPN client information at all

Output the final weighted score: score = 0.5×Part1 + 0.5×Part2
