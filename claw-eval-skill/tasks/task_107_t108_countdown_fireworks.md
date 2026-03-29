---
id: task_107_t108_countdown_fireworks
name: Claw-Eval T108_countdown_fireworks
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/107_00_t108_countdown_fireworks.json
    dest: config.json
---

## Prompt

The container has the following file:
- /workspace/fixtures/config.json — countdown and fireworks configuration

Please read the config file, then generate /workspace/output.html to create a countdown timer with fireworks:
1. Display a countdown starting from the configured number of seconds
2. Use the specified font size, colors, and background
3. When the countdown reaches zero, display the celebration message
4. Launch animated fireworks with the configured colors and particle count
5. Fireworks should burst from multiple points with expanding particle effects

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T108_countdown_fireworks`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Score the generated countdown + fireworks webpage screenshots:
- Dark background visible? (0.10)
- Countdown number or 'Happy New Year!' message visible? (0.25)
- Firework particles/explosions visible (colorful bursts)? (0.25)
- Multiple firework colors used? (0.15)
- Clean, centered layout? (0.10)
- Overall visual appeal and polish? (0.15)

===RUBRIC===

Score the countdown/fireworks animation across sequential frames ~0.5s apart:
- Countdown numbers decrease across early frames? (0.25)
- Fireworks appear after countdown ends? (0.25)
- Particles spread outward from explosion points? (0.20)
- Multiple firework bursts at different positions? (0.15)
- 'Happy New Year!' message appears after countdown? (0.15)
