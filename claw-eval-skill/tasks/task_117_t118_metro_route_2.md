---
id: task_117_t118_metro_route_2
name: Claw-Eval T118_metro_route_2
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/117_00_t118_metro_route_2.png
    dest: 地铁2.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/地铁2.png — a metro/subway map image

Please first use tools to view the metro map, then generate /workspace/output.html to create an interactive route display page:
1. Reproduce the metro map using SVG with correct line colors and station positions
2. Highlight a specific route from one station to another
3. Dim or fade non-route lines to make the route stand out
4. Clearly mark the start and end stations
5. Include a route description panel showing the stations along the route
6. Add animation showing the route being traced from start to end

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T118_metro_route_2`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the animated metro route webpage against the reference metro map.
CRITICAL: The underlying map must accurately match the reference, not just look like a generic subway map.
- Does the metro map match the reference (correct lines, colors, stations)? (0.25)
- Is the highlighted route clearly visible and distinct? (0.15)
- Are station names along the route correct? (0.15)
- Non-route lines appropriately dimmed/faded? (0.10)
- Start and end stations clearly marked? (0.10)
- Route description/info panel with correct station names? (0.10)
- Clean, professional layout? (0.15)
Score LOW if the map doesn't match the reference even though the UI looks nice.

===RUBRIC===

Score the route animation across sequential frames ~0.5s apart:
- Route highlight progresses along the path between frames? (0.30)
- Stations along the route light up sequentially? (0.25)
- Animation direction follows logical station order? (0.20)
- Non-highlighted portions remain dimmed? (0.15)
- Smooth visual progression between frames? (0.10)
