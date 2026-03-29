---
id: task_104_t105_clock
name: Claw-Eval T105_clock
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/104_00_t105_clock.json
    dest: config.json
---

## Prompt

The container has the following file:
- /workspace/fixtures/config.json — clock configuration parameters

Please read the config file, then generate /workspace/output.html to create an animated analog clock based on the config:
1. Display a circular clock face with hour/minute/second hands
2. Use the colors, sizes, and options specified in the config
3. The clock should show the correct time for the configured timezone
4. Second hand should move smoothly in real-time
5. Include number markers or tick marks as configured

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T105_clock`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Score the generated clock webpage screenshots:
- Circular clock face with clear border? (0.2)
- Hour/minute/second hands visible and distinct? (0.2)
- Tick marks and/or numbers 1-12 visible? (0.2)
- Clean centered design? (0.2)
- Colors consistent and well-chosen? (0.2)

===RUBRIC===

Score the clock animation across sequential frames captured ~0.5s apart:
- Second hand moves between frames? (0.3)
- Movement appears smooth and clockwise? (0.2)
- Position changes consistent with ~0.5s intervals? (0.2)
- Hour/minute hands relatively stationary over 5s? (0.15)
- Clock shows a plausible time? (0.15)
