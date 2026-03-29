---
id: task_124_t125_doc_reference_verification
name: Claw-Eval T125_doc_reference_verification
category: doc_search
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/124_00_t125_doc_reference_verification.pdf
    dest: Li_VL-RewardBench_A_Challenging_Benchmark_for_Vision-Language_Generative_Reward_Models_CVPR_2025_paper.pdf
---

## Prompt

The container has the following file:
- /workspace/fixtures/Li_VL-RewardBench_A_Challenging_Benchmark_for_Vision-Language_Generative_Reward_Models_CVPR_2025_paper.pdf

I'm sorting out paper references. Scan the reference list of the provided
paper. Identify all citations that are listed as 'arXiv preprints' and verify
which of these arXiv papers have been officially accepted or published in
formal academic conferences as of March 19, 2026. Generate a file named
/workspace/updated_publications.csv containing exactly two columns:
Paper Title and Formal Venue.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `multimodal`
Original task id: `T125_doc_reference_verification`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Ground Truth (15 arXiv papers now published at formal venues):
1. Molmo and pixmo: Open weights and open data for state-of-the-art multimodal models. → CVPR 2025
2. Mme: A comprehensive evaluation benchmark for multimodal large language models. → NeurIPS 2025
3. Video-mme: The first-ever comprehensive evaluation benchmark of multi-modal llms in video analysis. → CVPR 2025
4. Rewardbench: Evaluating reward models for language modeling. → Findings of NAACL 2025
5. MathVista: Evaluating Mathematical Reasoning of Foundation Models in Visual Contexts. → ICLR 2024
6. Scaling LLM Test-Time Compute Optimally Can be More Effective than Scaling Parameters for Reasoning. → ICLR 2025
7. Learning to summarize from human feedback. → NeurIPS 2020
8. Aligning large multimodal models with factually augmented rlhf. → Findings of ACL 2024
9. Large language models are not fair evaluators. → ACL 2024
10. Style over substance: Evaluation biases for large language models. → COLING 2025
11. Llava-critic: Learning to evaluate multimodal models. → CVPR 2025
12. RLAIF-V: Aligning MLLMs through Open-Source AI Feedback for Super GPT-4V Trustworthiness. → CVPR 2025
13. Mmmu-pro: A more robust multi-discipline multimodal understanding benchmark. → ACL 2025
14. MATHVERSE: Does Your Multi-modal LLM Truly See the Diagrams in Visual Math Problems?. → ECCV 2024
15. RMB: Comprehensively benchmarking reward models in LLM alignment. → ICLR 2025

Start with a base score of 1.0. Apply the following deductions (minimum score 0.0):
- -0.1 pts for each paper in the Ground Truth that is missing from the output,
  or has an incorrect formal venue.
- -0.1 pts for each extra paper included in the output that is NOT in the Ground
  Truth (e.g., papers still on arXiv or hallucinated papers).

Evaluate the CSV output against the ground truth using these criteria.
Output a score between 0.0 and 1.0.
