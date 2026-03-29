---
id: task_108_t109_score_canon
name: Claw-Eval T109_score_canon
category: multimodal_webpage
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/108_00_t109_score_canon.png
    dest: Canon1.png
---

## Prompt

The container has the following file:
- /workspace/fixtures/Canon1.png — a sheet music image of Canon in D

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
Original task id: `T109_score_canon`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Compare the candidate SVG sheet music against the reference image of Canon in D.

REFERENCE CONTENT — use this to judge whether the notes are correctly drawn:

Title: 'Canon in D', Composer: Johann Pachelbel, Arr. by lemontart, Tempo: quarter=100
Key: D Major (2 sharps: F# and C#), Time: 4/4
Two staves: treble clef (top) + bass clef (bottom), joined by brace.
8 measures total, in two lines of 4 measures each.

LINE 1 — Measures 1-4 (bass solo, treble rests):
  Right hand: whole rests in ALL of measures 1-4.
  Left hand: 8 eighth notes per measure (pairs of two). Pattern:
    M1 (D-A): D3,F#3 / A3,D4 / A2,C#3 / E3,A3
    M2 (Bm-F#m): B2,D3 / F#3,B3 / F#2,A2 / C#3,F#3
    M3 (G-D): G2,B2 / D3,G3 / D3,F#3 / A3,D4
    M4 (G-A): G2,B2 / D3,G3 / A2,C#3 / E3,A3
  Dynamic: p at start of M1, crescendo mark near end of M4.

LINE 2 — Measures 5-8 (melody enters):
  Left hand: repeats the same 4-measure pattern as M1-M4 (ostinato).
  Right hand enters with half notes (2 beats each):
    M5: F#5 (beats 1-2), E5 (beats 3-4)
    M6: D5 (beats 1-2), C#5 (beats 3-4)
    M7: B4 (beats 1-2), A4 (beats 3-4)
    M8: B4 (beats 1-2), C#5 (beats 3-4)
  Dynamic: m (mf) at start of M5.

KEY FEATURES to verify:
1. Treble clef MUST be empty (rests) in measures 1-4.
2. Bass eighth-note pairs should show clear UP-DOWN arpeggio motion, NOT a flat repeated pattern.
3. Each measure's bass notes should be at DIFFERENT heights (D-A, Bm-F#m, G-D, G-A progressions).
4. Right hand melody in M5-8 should DESCEND then RISE: F#5→E5→D5→C#5→B4→A4→B4→C#5.

SCORING:
- Are measures 1-4 treble rests correct? (0.10)
- Do bass pairs in M1-M4 show distinct arpeggio shapes at different heights per measure? (0.30)
- Does the treble melody in M5-8 follow the descending-then-rising half-note pattern? (0.25)
- Correct key signature (2 sharps), time (4/4), dynamics (p, m), clefs? (0.10)
- Title, composer, tempo marking, layout? (0.10)
- Overall visual match to reference image? (0.15)

Score 0.0-0.2 if bass is a flat repeated pattern (same shape every measure) or treble is not resting in M1-4.
Score 0.2-0.4 if some measures have different bass shapes but melody is wrong.
Score 0.4-0.7 if general contour is right but specific pitches are off.
Score 0.7-1.0 only if bass arpeggio pattern varies correctly per measure AND melody descends then rises.
