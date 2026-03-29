---
id: task_134_t135_video_room_floorplan
name: Claw-Eval T135_video_room_floorplan
category: video_image
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/134_00_t135_video_room_floorplan.mp4
    dest: video.mp4
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.mp4

Based on this video, reconstruct the floor plan layout of the room as a top-down 2D diagram. Orientation: The direction you face at the very start of the video defines the top edge of the floor plan. The right side of that initial view maps to the right edge, and the left side maps to the left edge. Maintain this orientation consistently throughout. Include all major objects that appear in the video, label them by name on the diagram, and accurately reflect their spatial relationships. Draw it as an SVG image and save it as /workspace/floorplan.png.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T135_video_room_floorplan`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate this floor plan for object coverage.

Ground-truth objects:
| Object | Expected Quantity |
|--------|-------------------|
| Dining Table | 1 |
| Kitchen Island | 1 |
| Counter Stools | 4 |
| Armchair | 2 |
| Cabinets | 1 |
| Sofa | 2 |
| Coffee Table | 2 |
| Window | 1 |
| TV | 1 |

For each object: score 1 if present, correctly labeled, AND quantity matches; 0 otherwise.
Synonym labels acceptable (Sofa=Couch, TV=Television, Cabinets=Cabinet).
Recall = sum of scores / 9.

Evaluate coverage only. Do NOT penalize for wrong position, size, or shape.
Extra objects not in ground truth should be ignored.

Score = Recall (0.0-1.0).

===RUBRIC===

Evaluate this floor plan for spatial relationship accuracy.

Ground-truth spatial relationships (10 pairs):
Directions: above/below (vertical ±22.5°), left/right (horizontal ±22.5°), top-left/top-right/bottom-left/bottom-right (diagonal quadrants).

1. Dining Table relative to Sofa (bottom): top-left
2. Cabinets relative to Window: bottom-left
3. Window relative to Armchairs: top-right
4. Armchairs relative to TV: left
5. Armchairs relative to Sofa (top): bottom-left
6. Kitchen Island relative to Dining Table: below
7. Dining Table relative to Coffee Table: top-left
8. Dining Table relative to Window: top-left
9. Coffee Table relative to Sofa (bottom): above
10. Cabinets relative to Armchairs: left

For each pair: score 1 if direction matches (lenient for small deviations), 0 otherwise.
If either object is missing, score = 0 for that pair.

Score = correct_pairs / 10 (0.0-1.0).
