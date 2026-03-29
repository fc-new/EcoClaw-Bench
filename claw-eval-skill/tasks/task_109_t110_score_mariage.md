---
id: task_109_t110_score_mariage
name: Claw-Eval T110_score_mariage
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/109_00_t110_score_mariage.png
    dest: mariage1.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/mariage1.png — a sheet music image of Mariage d'Amour

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
Original task id: `T110_score_mariage`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the candidate SVG sheet music against the reference image of Mariage d'Amour.

REFERENCE CONTENT — use this to judge whether the notes are correctly drawn:

Title: 'Mariage d'Amour', Composer: Paul de Senneville
Key: g minor (2 flats: Bb, Eb), Time: starts 4/4 (C), changes to 5/4 in M3, back to C in M4.
Two staves: treble clef (top) + bass clef (bottom). 3 complete measures shown.

MEASURE 1 (4/4):
  Right hand: whole rest (completely empty).
  Left hand: 8 eighth notes in pairs (g minor arpeggio):
    Pair 1: G2, D3 / Pair 2: G3, Bb3 / Pair 3: D3, G3 / Pair 4: Bb3, D3
    Pattern: rises from low G2 up to Bb3, then falls back.

MEASURE 2 (4/4):
  Right hand: whole rest (still empty).
  Left hand: identical to M1 — G2,D3 / G3,Bb3 / D3,G3 / Bb3,D3

MEASURE 3 (5/4 — the dramatic entry):
  Time signature changes to 5/4 (5 beats).
  Left hand: 5 pairs (10 eighth notes):
    Pair 1: G2, D3 / Pair 2: G3, Bb3 / Pair 3: D3, G3 / Pair 4: Bb3, D3 / Pair 5: G2, D3
  Right hand enters with a FAST ascending run of sixteenth notes:
    Beat 1: eighth rest, then D5, Eb5 (two sixteenths — quick start)
    Beat 2: F5, G5, A5, Bb5 (four sixteenths — ascending scale)
    Beat 3: C6, D6, C6, Bb5 (four sixteenths — peak then descend)
    Beat 4: A5, G5, A5, Bb5 (four sixteenths — oscillating)
    Beat 5: D5 (quarter note — lands and holds)
  This DENSE beamed sixteenth-note passage is the most distinctive visual feature.

KEY FEATURES to verify:
1. M1-M2: treble must be EMPTY (rests), bass has arpeggiated eighth-note pairs.
2. M3: time signature changes to 5/4. Right hand suddenly fills with DENSE beamed sixteenth notes.
3. The sixteenth-note run in M3 goes UP (D5→Eb5→F5→G5→A5→Bb5→C6→D6) then back DOWN.
4. Visual contrast: M1-M2 are sparse (bass only), M3 is very dense (many beamed notes in treble).

SCORING:
- Are M1-M2 treble rests correct with bass arpeggio pattern? (0.20)
- Does M3 show the time signature change to 5/4? (0.10)
- Does M3 right hand show a dense ascending sixteenth-note run (many beamed notes going UP)? (0.25)
- Is there a clear visual contrast between sparse M1-M2 and dense M3? (0.15)
- Correct key signature (2 flats), clefs, barlines? (0.10)
- Title, composer, layout? (0.10)
- Overall visual match to reference? (0.10)

Score 0.0-0.2 if M3 does not have a dense ascending run, or M1-M2 are not sparse.
Score 0.2-0.4 if the ascending run exists but note positions are mostly wrong.
Score 0.4-0.7 if the general structure (sparse→dense) is correct but details are off.
Score 0.7-1.0 only if the ascending scale run in M3 and the sparse M1-M2 bass pattern closely match.
