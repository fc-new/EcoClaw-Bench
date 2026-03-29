---
id: task_013_4195adea_9fa5_4f25_91ef_ebd6c57cfb88
name: Frontierscience physics 013
category: frontierscience
grading_type: automated
timeout_seconds: 300
workspace_files: []
---

## Prompt

A thin-walled insulated container of mass `\(M\)` (ignoring the thickness of the container) floats in space (considered as a vacuum), initially at rest, is filled with `\(N_0\)` molecules of nitrogen gas (`\( N_2 \)`), at an equilibrium temperature of `\(T_0\)`, and the mass per molecule of nitrogen of `\(m\)`. In this case, we assume that `\(M\gg N_0m\)`. A small hole appears in the container, which is so small that it is much smaller than the mean free path of the gas (that is, `\( \sqrt{A} << \lambda \)` where `\( A \)` is the area of the hole and `\( \lambda \)` is the mean free path length). The rate of escape of the gas is so slow that we can treat the gas in the container as an equilibrium state of uniform temperature at every instant. The Boltzmann constant is `\(k_B\)` and all temperatures are absolute.

What is the equilibrium temperature `\(T\)` when there are `\(N\)` nitrogen molecules left in the container?

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
    expected = "`\\( t = t_0(\\frac{n}{n_0})^{\\frac{1}{5}} \\) `"
    if normalized == expected:
        result["answer_match"] = 1.0
    return result
```
