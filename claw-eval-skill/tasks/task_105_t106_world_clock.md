---
id: task_105_t106_world_clock
name: Claw-Eval T106_world_clock
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/105_00_t106_world_clock.json
    dest: config.json
---

## Prompt

The container has the following file:
- /workspace/fixtures/config.json — world clock configuration

Please read the config file, then generate /workspace/output.html to display multiple analog clocks showing different time zones:
1. Show one clock for each city defined in the config
2. Each clock should display the correct time for its timezone
3. Use the specified colors for each clock
4. Label each clock with its city name
5. Arrange clocks according to the layout setting
6. All clocks should animate in real-time

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T106_world_clock`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Score the generated world clock webpage screenshots:
- Four distinct clock faces visible? (0.25)
- Each clock labeled with city name (北京, London, New York, Tokyo)? (0.20)
- Clocks arranged in clean horizontal/grid layout? (0.15)
- Each clock has hands (hour/minute/second)? (0.20)
- Distinct colors per clock, overall clean design? (0.20)

===RUBRIC===

Score the world clock animation across sequential frames ~0.5s apart:
- Second hands move between frames on all clocks? (0.30)
- Different clocks show different times (timezone offsets)? (0.25)
- Movement is smooth and clockwise? (0.20)
- Clocks remain synchronized (all updating each frame)? (0.15)
- Overall animation looks natural? (0.10)
