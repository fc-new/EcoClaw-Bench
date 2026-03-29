---
id: task_114_t115_score_mariage_animated
name: Claw-Eval T115_score_mariage_animated
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/114_00_t115_score_mariage_animated.png
    dest: mariage1.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/mariage1.png — a sheet music image of Mariage d'Amour

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
Original task id: `T115_score_mariage_animated`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the animated sheet music webpage against the reference Mariage d'Amour score.

REFERENCE CONTENT — the score should match these details:
Title: 'Mariage d'Amour', Composer: Paul de Senneville
Key: g minor (2 flats: Bb, Eb), Time: 4/4→5/4→4/4. 3 measures.
M1-2 (4/4): Treble whole rests. Bass: eighth-note arpeggio pairs G2,D3/G3,Bb3/D3,G3/Bb3,D3.
M3 (5/4): DRAMATIC ENTRY — treble enters with dense beamed sixteenth notes:
  An ascending run D5→Eb5→F5→G5→A5→Bb5→C6→D6, then descending, ending on D5 quarter.
  This dense passage is the MOST distinctive visual element.
Visual contrast: M1-2 sparse (bass only) → M3 very dense (many beamed sixteenths in treble).

SCORING:
- M1-M2 treble rests + bass arpeggio? (0.15)
- M3 shows dense ascending sixteenth-note run in treble (many beamed notes going UP)? (0.20)
- Clear visual contrast between sparse M1-2 and dense M3? (0.15)
- Piano keyboard present below score? (0.10)
- Play button and note highlight visible? (0.10)
- Correct key (2 flats), time signature change, clefs? (0.10)
- Layout clean and professional? (0.10)
- Title, composer? (0.10)

Score LOW if M3 does not show a dense ascending run or M1-M2 are not sparse.

===RUBRIC===

Score the playback animation across sequential frames ~0.5s apart:
- Different notes highlighted in different frames? (0.30)
- Piano keys light up corresponding to played notes? (0.25)
- Highlight moves left-to-right through the score? (0.20)
- Progression speed appears reasonable? (0.15)
- Visual change between consecutive frames is clear? (0.10)
