---
id: task_106_t107_solar_system
name: Claw-Eval T107_solar_system
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/106_00_t107_solar_system.json
    dest: planets.json
---

## Prompt

The container has the following file:
- /workspace/fixtures/planets.json — solar system configuration

Please read the config file, then generate /workspace/output.html to create an animated solar system visualization:
1. Display the sun at the center with the specified color and size
2. Show each planet orbiting the sun along its defined orbit path
3. Use the correct colors, sizes, and orbital radii from the config
4. Inner planets should orbit faster than outer planets (follow the period settings)
5. Show orbit paths and planet labels as configured
6. Saturn should display a ring if configured

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T107_solar_system`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Score the generated solar system webpage screenshots:
- Sun visible at center, bright yellow/gold? (0.15)
- At least 6 planets visible at different orbit distances? (0.20)
- Orbit paths/circles shown? (0.15)
- Planet labels visible? (0.15)
- Saturn has a visible ring? (0.10)
- Dark space background? (0.10)
- Planets have distinct colors and proportional sizes? (0.15)

===RUBRIC===

Score the solar system animation across sequential frames ~0.5s apart:
- Planets move along their orbits between frames? (0.30)
- Inner planets move faster than outer planets? (0.25)
- Movement follows circular/elliptical paths? (0.20)
- Sun remains stationary at center? (0.15)
- Animation appears smooth? (0.10)
