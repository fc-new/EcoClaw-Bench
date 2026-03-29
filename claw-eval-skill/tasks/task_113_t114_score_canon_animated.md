---
id: task_113_t114_score_canon_animated
name: Claw-Eval T114_score_canon_animated
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/113_00_t114_score_canon_animated.png
    dest: Canon1.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/Canon1.png — a sheet music image of Pachelbel's Canon in D

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
Original task id: `T114_score_canon_animated`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the animated sheet music webpage against the reference Canon in D score.

REFERENCE CONTENT — the score should match these details:
Title: 'Canon in D', Key: D Major (2 sharps), Time: 4/4, Tempo: 100
8 measures: M1-4 bass solo (treble rests), M5-8 melody enters.
Bass (M1-4): eighth-note pairs forming arpeggios — each measure at DIFFERENT heights:
  M1: D3,F#3 / A3,D4 / A2,C#3 / E3,A3
  M2: B2,D3 / F#3,B3 / F#2,A2 / C#3,F#3
  M3: G2,B2 / D3,G3 / D3,F#3 / A3,D4
  M4: G2,B2 / D3,G3 / A2,C#3 / E3,A3
Treble (M5-8): half notes descending then rising: F#5,E5,D5,C#5,B4,A4,B4,C#5

SCORING:
- Do bass notes vary per measure (not a flat repeated pattern)? (0.20)
- Does treble rest in M1-4 and enter with descending half notes in M5+? (0.15)
- Note positions on staff match reference? (0.15)
- Piano keyboard present below score? (0.10)
- Play button and note highlight/playback indicator visible? (0.10)
- Correct key (2 sharps), time (4/4), clefs? (0.10)
- Layout clean and professional? (0.10)
- Title, composer, dynamics? (0.10)

Score LOW if bass is flat repeated pattern or treble notes in M1-4.

===RUBRIC===

Score the Canon playback animation across sequential frames ~0.5s apart:
- Different notes highlighted in different frames? (0.30)
- Piano keys light up corresponding to played notes? (0.25)
- Highlight moves left-to-right through the score? (0.20)
- Progression speed appears reasonable? (0.15)
- Visual change between consecutive frames is clear? (0.10)
