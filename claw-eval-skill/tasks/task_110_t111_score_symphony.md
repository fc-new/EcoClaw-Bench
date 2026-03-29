---
id: task_110_t111_score_symphony
name: Claw-Eval T111_score_symphony
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/110_00_t111_score_symphony.png
    dest: symphony1.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/symphony1.png — a sheet music image of a symphony score

Please first use tools to view the sheet music image, then generate /workspace/output.html to reproduce this score using SVG:
1. Include the title and composer information
2. Draw the staves with correct clefs
3. Correctly display the key signature and time signature
4. Reproduce the note pitches, durations, and positions as accurately as possible
5. Include barlines, stems, beams, and other notation details

You can use tools to preview and iteratively adjust until you are satisfied.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T111_score_symphony`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the candidate SVG sheet music against the reference image of Symphony No. 5 Mvt. 1.

REFERENCE CONTENT — use this to judge whether the notes are correctly drawn:

Title: 'Symphony No. 5 Mvt. 1', Composer: Beethoven, Tempo: quarter=170
Key: C minor (3 flats: Bb, Eb, Ab), Time: 2/4
Two staves: treble (top) + bass (bottom), joined by brace. 5 measures shown.

THE FAMOUS 'FATE' MOTIF — short-short-short-LONG:

MEASURE 1 (2/4):
  Right hand: eighth rest, then THREE beamed eighth notes all on G4.
  Left hand: eighth rest, then THREE beamed eighth notes — octave doubles G2+G3.
  Visual: a small gap (rest) then 3 notes beamed together.

MEASURE 2 (2/4):
  Right hand: one half note on Eb4 (fills entire measure, HELD note).
  Left hand: one half note — octave doubles Eb2+Eb3.
  Visual: a single long note — stark contrast to the busy M1.

MEASURE 3 (2/4):
  Right hand: eighth rest, then THREE beamed eighth notes all on F4.
  Left hand: eighth rest, then THREE beamed eighth notes — octave doubles F2+F3.
  Visual: same rest-then-3-notes pattern as M1, but at a LOWER pitch.

MEASURE 4 (2/4):
  Right hand: half note on D4, with tie to next measure.
  Left hand: half note — octave doubles D2+D3, with tie.

MEASURE 5 (2/4):
  Right hand: half note D4 (continuation from tie).
  Left hand: half note D2+D3 (continuation). Clef change to treble at end.

KEY FEATURES to verify:
1. The 'da-da-da-DUM' pattern: M1 has rest + 3 beamed eighth notes, M2 has one held note.
   Then it REPEATS: M3 has rest + 3 beamed notes, M4 has one held note.
2. M1 notes (G4) are HIGHER than M3 notes (F4) — the motif steps DOWN.
3. M2 held note (Eb4) is LOWER than M1 notes (G4) — big drop.
4. Both staves play the SAME rhythmic pattern (both have the rest+3 in M1,M3 and held in M2,M4).
5. Left hand plays octave doubles throughout.

SCORING:
- Is the rest + 3 beamed eighth notes pattern visible in M1 and M3? (0.25)
- Are M2 and M4 single held notes (half notes), creating short-short-short-LONG rhythm? (0.20)
- Do M1 notes sit HIGHER on staff than M3 notes (G vs F, stepping down)? (0.15)
- Do both staves mirror the same rhythmic pattern? (0.10)
- Correct key signature (3 flats), time (2/4), clefs, ties in M4-M5? (0.10)
- Title, composer, tempo, layout? (0.10)
- Overall visual match to reference? (0.10)

Score 0.0-0.2 if the da-da-da-DUM rhythmic pattern is not recognizable.
Score 0.2-0.4 if there are groups of 3 notes but the held notes or pitch steps are wrong.
Score 0.4-0.7 if the motif pattern is recognizable but pitches or ties are inaccurate.
Score 0.7-1.0 only if the short-short-short-LONG pattern with correct pitch descent closely matches.
