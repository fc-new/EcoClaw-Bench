---
id: task_112_t113_metro_map_2
name: Claw-Eval T113_metro_map_2
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/112_00_t113_metro_map_2.png
    dest: 地铁2.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/地铁2.png — a metro/subway map image

Please first use tools to view the metro map, then generate /workspace/output.html to reproduce this map using SVG:
1. Draw all subway lines using their corresponding colors
2. Mark all stations with dots or circles
3. Label station names
4. Use special markers for transfer/interchange stations (e.g., larger circles or multi-color markers)
5. Reproduce the line routes and curves as closely as possible to the original

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T113_metro_map_2`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the candidate SVG metro map against the reference NYC subway map (Midtown Manhattan & Queens area).

REFERENCE CONTENT DESCRIPTION (use this to verify map accuracy):
This is the mid/upper portion of the New York City subway map, covering Midtown Manhattan, Upper Manhattan, and Queens.

KEY LINES AND COLORS:
- Lines 1/2/3: RED — run along the west side (Broadway/7th Ave), from 157 St down through Times Sq
- Lines 4/5/6: GREEN — run along the east side (Lexington Ave), through Grand Central, up to Harlem
- Lines A/C: BLUE — run along 8th Ave/Central Park West, from 145 St down through Columbus Cir
- Lines N/Q/R/W: YELLOW — run through Times Sq, 5th Ave, into Queens
- Lines D/F: ORANGE — run through Rockefeller Center, Bryant Park
- Line 7: PURPLE — runs east-west from Times Sq 42 St to Flushing (Queens)
- Lines E/F: extend into Queens (Jamaica/Forest Hills)
- Line G: LIGHT GREEN — Brooklyn-Queens connector

KEY STATIONS AND LANDMARKS:
- Times Sq / 42 St — massive hub where 1/2/3, 7, N/Q/R/W, S converge (shown as large complex)
- Grand Central — 42 St, 4/5/6/7/S lines
- Columbus Circle / 59 St — 1/A/C/B/D lines
- Lexington Av / 59 St — major east side transfer
- 72 St, 86 St, 96 St — along both west and east side lines
- 125 St / Harlem — important uptown stations
- Queens Plaza, Court Sq — Queens transfer hubs
- Central Park shown as GREEN rectangle in the middle
- 'Manhattan' labeled in large text, 'Queens' on the right

MAP LAYOUT:
- Manhattan runs vertically (north at top)
- Central Park is a prominent GREEN rectangle in the center
- Queens is on the RIGHT/EAST side
- The Harlem/East Rivers separate the boroughs

SCORING CRITERIA:
- Are the major subway lines present with correct colors (red 1/2/3, green 4/5/6, blue A/C, yellow N/Q/R, purple 7)? (0.25)
- Are key stations labeled correctly (Times Sq, Grand Central, Columbus Cir, 125 St, Queens Plaza)? (0.25)
- Is the topology correct (which lines meet at which transfer stations)? (0.20)
- Is the geographic layout correct (Manhattan vertical, Central Park green, Queens on right)? (0.15)
- Are transfer stations shown with correct multi-line indicators? (0.10)
- Clean rendering with legible station names? (0.05)

Score 0.0-0.2 if it's a generic subway map or wrong city.
Score 0.2-0.4 if it's NYC but most station names or line colors are wrong.
Score 0.4-0.7 if major lines and stations are present but with significant errors.
Score 0.7-1.0 only if it closely matches the reference map's lines, colors, and stations.
