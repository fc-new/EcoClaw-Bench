---
id: task_070_t71_video_mme_coauthor_papers
name: Claw-Eval T71_video_mme_coauthor_papers
category: research
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Find out all the published peer-reviewed conference papers co-authored by the 4th and 5th authors of the Video-MME paper.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T71_video_mme_coauthor_papers`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate how completely and accurately the response identifies co-authored papers by the 4th and 5th authors of Video-MME.

PREREQUISITE FACTS:
- 4th author of Video-MME: Lei Li
- 5th author of Video-MME: Shuhuai Ren

For each item below, award full weight if the paper is correctly identified (title or clear description + venue), 0 otherwise.
Final score = sum of awarded weights.

CONFERENCE PAPERS (peer-reviewed, co-authored by both, total 100%):
1. [Weight 10%] AAAI — TEMPLE: Temporal Preference Learning of Video LLMs via Difficulty Scheduling and Pre-SFT Alignment
2. [Weight 10%] CVPR — GroundingME: Exposing the Visual Grounding Gap in MLLMs through Multi-Dimensional Evaluation
3. [Weight 10%] ACM MM — TimeChat-Online: 80% Visual Tokens are Naturally Redundant in Streaming Videos
4. [Weight 10%] CVPR — Video-MME: The first-ever comprehensive evaluation benchmark of multi-modal LLMs in video analysis
5. [Weight 10%] ECCV — Vitatecs: A diagnostic dataset for temporal concept understanding of video-language models
6. [Weight 10%] NeurIPS — FETV: A Benchmark for Fine-Grained Evaluation of Open-Domain Text-to-Video Generation
7. [Weight 10%] ACL — Delving into the Openness of CLIP
8. [Weight 10%] EMNLP — CascadeBERT: Accelerating Inference of Pre-trained Language Models via Calibrated Complete Models Cascade
9. [Weight 10%] EMNLP — Dynamic Knowledge Distillation for Pre-trained Language Models
10. [Weight 10%] EMNLP — Text AutoAugment: Learning Compositional Augmentation Policy for Text Classification

BONUS (ArXiv preprints, not required but good to mention):
- MiMo-VL
- MiMo-v2-flash technical report
- MiMo-Audio
- MiMo: Unlocking the Reasoning Potential of Language Model
