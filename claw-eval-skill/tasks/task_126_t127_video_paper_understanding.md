---
id: task_126_t127_video_paper_understanding
name: Claw-Eval T127_video_paper_understanding
category: video_qa
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/126_00_t127_video_paper_understanding.mp4
    dest: video.mp4
---

## Prompt

The container has the following file:
- /workspace/fixtures/video.mp4

I find this paper very interesting. May I ask what the full title of the paper is? In the Task-adaptive Multimodal Alignment module, what are the specific network interaction mechanisms and decoupled training objectives of Meta Queries? Please help me list the formulas; I don't have a background in deep learning, so please explain it in a simple and easy-to-understand way. Also, has its code been open-sourced?

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T127_video_paper_understanding`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth:
Paper title: "OmniTransfer: All-in-one Framework for Spatio-temporal Video Transfer"

Part 1 - Correct Full Name (0.2):
Must state the exact paper title. Minor typos acceptable. Score 0.2 if correct, 0 otherwise.

Part 2 - Core Mechanism and Training (0.4):
- Interaction mechanism explanation (0.2): Must mention Qwen-2.5-VL replacing T5, explain Meta Queries' different treatment for time-related tasks (aggregating timeline cues + first frames) vs appearance-related tasks (integrating identity style + prompt semantics).
- Decoupled training objectives (0.2): Must accurately describe 3 training stages: Stage 1 trains diffusion module, Stage 2 trains connector, Stage 3 joint fine-tuning.

Part 3 - Formula Accuracy (0.15):
Must list the cross-attention formula: Attn(Q_tgt, K_MLLM, V_MLLM) with basic variable explanations. Full 0.15 if formula matches; 0 if structural errors.

Part 4 - Plain Expression (0.15):
Uses metaphors/analogies easy for non-professionals (e.g. dictionary, guide). If entirely rigid academic jargon, score 0.

Part 5 - Open Source Judgment (0.1):
Must explicitly answer "Already open-sourced" or equivalent. Score 0.1 if correct.

Final score = sum of all parts (0.0-1.0).
