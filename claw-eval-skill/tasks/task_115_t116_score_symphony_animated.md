---
id: task_115_t116_score_symphony_animated
name: Claw-Eval T116_score_symphony_animated
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/115_00_t116_score_symphony_animated.png
    dest: symphony1.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/symphony1.png — a sheet music image of a symphony score

Please first use tools to view the sheet music image, then generate /workspace/output.html to create an interactive score playback page:
1. Reproduce the score using SVG (staves, notes, clefs, etc.)
2. Draw a piano keyboard below the score
3. Add a "Play" button
4. When play is clicked:
   - Notes should highlight sequentially from left to right
   - Corresponding piano keys should light up in sync
   - Use the Web Audio API to produce the correct pitches
5. Playback speed should be appropriate and animation smooth

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T116_score_symphony_animated`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the animated sheet music webpage against the reference Symphony No. 5 score.

REFERENCE CONTENT — the score should match these details:
Title: 'Symphony No. 5 Mvt. 1', Composer: Beethoven, Tempo: 170
Key: C minor (3 flats), Time: 2/4. 5 measures.
THE FAMOUS 'da-da-da-DUM' MOTIF:
  M1: rest + 3 beamed eighth notes on G4 (both staves). Left hand: octave G2+G3.
  M2: one half note on Eb4 (HELD, big drop from G). Left: Eb2+Eb3.
  M3: rest + 3 beamed eighth notes on F4 (LOWER than M1). Left: F2+F3.
  M4: one half note on D4, tied to M5. Left: D2+D3.
Pattern: rest+3notes, HOLD, rest+3notes, HOLD — the motif steps DOWN (G→Eb, F→D).
Both staves mirror the same rhythm.

SCORING:
- Is rest + 3 beamed notes pattern visible in M1 and M3? (0.20)
- Are M2 and M4 held half notes (short-short-short-LONG rhythm)? (0.15)
- Do M1 notes sit higher than M3 (G vs F, stepping down)? (0.10)
- Both staves mirror same pattern? (0.05)
- Piano keyboard present below score? (0.10)
- Play button and note highlight visible? (0.10)
- Correct key (3 flats), time (2/4), ties M4-M5? (0.10)
- Layout clean, title, composer? (0.10)
- Overall visual match to reference? (0.10)

Score LOW if the da-da-da-DUM pattern is not recognizable.

===RUBRIC===

Score the playback animation across sequential frames ~0.5s apart:
- Different notes highlighted in different frames? (0.30)
- Piano keys light up corresponding to played notes? (0.25)
- Highlight moves left-to-right through the score? (0.20)
- Progression speed appears reasonable? (0.15)
- Visual change between consecutive frames is clear? (0.10)
