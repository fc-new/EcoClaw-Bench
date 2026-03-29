---
id: task_111_t112_metro_map_1
name: Claw-Eval T112_metro_map_1
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/111_00_t112_metro_map_1.png
    dest: 地铁1.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/地铁1.png — a metro/subway map image

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
Original task id: `T112_metro_map_1`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the candidate SVG metro map against the reference NYC subway map (lower Manhattan & Brooklyn area).

REFERENCE CONTENT DESCRIPTION (use this to verify map accuracy):
This is the southern portion of the New York City subway map, covering lower Manhattan and Brooklyn.

KEY LINES AND COLORS:
- Lines 1/2/3: RED — run along the west side of Manhattan (7th Ave), through Chambers St, to Brooklyn
- Lines 4/5/6: GREEN — run along the east side (Lexington Ave), through Brooklyn Bridge to Brooklyn
- Lines A/C/E: BLUE — run along 8th Ave, through West 4 St, down to WTC/Fulton St area
- Lines N/Q/R: YELLOW — run through Canal St, City Hall area
- Lines D/F: ORANGE — run through West 4 St, Broadway-Lafayette
- Lines J/M/Z: BROWN — run along the Williamsburg Bridge to Brooklyn
- Line G: LIGHT GREEN — runs through Brooklyn (no Manhattan service)
- Line 7: PURPLE — appears at the top connecting to Queens
- PATH trains: shown as dashed lines to New Jersey

KEY STATIONS AND LANDMARKS:
- West 4 St/Washington Sq — major transfer hub (A/C/E/D/F meet)
- Canal St — multiple lines cross here
- Fulton St — major hub in Financial District
- Brooklyn Bridge/Chambers St — 4/5/6 cross the East River
- WTC (World Trade Center) — PATH and E train
- Atlantic Av — major Brooklyn hub (many lines converge)
- Borough Hall, Court St, Jay St MetroTech — Brooklyn downtown hubs
- South Ferry / Whitehall St — southern tip of Manhattan
- Battery Park area at the bottom-left of Manhattan

MAP LAYOUT:
- Manhattan is on the LEFT side, Brooklyn on the RIGHT
- The East River separates them (lines cross via bridges/tunnels)
- Background color is grayish-blue, with 'Brooklyn' labeled in large text

SCORING CRITERIA:
- Are the major subway lines present with correct colors (red 1/2/3, green 4/5/6, blue A/C/E, etc.)? (0.25)
- Are key stations labeled correctly (Fulton St, WTC, Canal St, Brooklyn Bridge, Atlantic Av)? (0.25)
- Is the topology correct (which lines connect at which transfer stations)? (0.20)
- Is the geographic layout correct (Manhattan left, Brooklyn right, East River between)? (0.15)
- Are transfer stations shown with correct multi-line indicators? (0.10)
- Clean rendering with legible station names? (0.05)

Score 0.0-0.2 if it's a generic subway map or wrong city.
Score 0.2-0.4 if it's NYC but most station names or line colors are wrong.
Score 0.4-0.7 if major lines and stations are present but with significant errors.
Score 0.7-1.0 only if it closely matches the reference map's lines, colors, and stations.
