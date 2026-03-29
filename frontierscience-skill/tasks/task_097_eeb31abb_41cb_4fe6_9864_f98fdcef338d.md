---
id: task_097_eeb31abb_41cb_4fe6_9864_f98fdcef338d
name: Frontierscience biology 097
category: frontierscience
grading_type: automated
timeout_seconds: 300
workspace_files: []
---

## Prompt

Molecular cloning is a technique that enables the generation of recombinant plasmids that can induce exogenous expression of certain genes. The first step of molecular cloning is to reverse transcribe the mRNA of the gene of interest into single-stranded cDNA. In an experiment, this was achieved through the use of oligo dT primers that specifically anneal to the poly-A tail of mRNA molecules, which is then extended by reverse transcriptase enzyme. The resultant cDNA molecules are then amplified through PCR and the products were visualized using agarose gel electrophoresis to ensure that the gene of interest was correctly amplified. However, the observed DNA band was estimated to be ~1 kb in size, which is far below the expected 3.7 kb of the gene of interest. After some troubleshooting steps, it was determined that this discrepancy was due to the type of reverse transcriptase enzyme selected for the experiment. What specific characteristic of the enzyme can explain this discrepancy?

Think step by step and solve the problem below. At the end of your response, write your final answer on a new line starting with “FINAL ANSWER”. It should be an answer to the question such as providing a number, mathematical expression, formula, or entity name, without any extra commentary or providing multiple answer attempts.

Write only the final answer to answer.txt in your workspace.

## Expected Behavior

The agent should solve the problem and write only the final answer to `answer.txt`.

## Grading Criteria

- [ ] File `answer.txt` created
- [ ] Final answer matches expected answer

## Automated Checks

```python
def grade(transcript: list, workspace_path: str) -> dict:
    import re
    from pathlib import Path
    result = {"file_created": 0.0, "answer_match": 0.0}
    path = Path(workspace_path) / "answer.txt"
    if not path.exists():
        return result
    result["file_created"] = 1.0
    text = path.read_text(encoding="utf-8", errors="ignore")
    normalized = re.sub(r"\s+", " ", text.strip().lower())
    expected = "the enzyme contains an rnase h domain"
    if normalized == expected:
        result["answer_match"] = 1.0
    return result
```
