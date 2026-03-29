---
id: task_028_f3ba1aae_2fc3_4d9b_a5a3_42bb91de4d7d
name: Frontierscience physics 028
category: frontierscience
grading_type: automated
timeout_seconds: 300
workspace_files: []
---

## Prompt

Consider a uniform three-dimensional object of elliptical cross section with mass `\(m\)`, the semi-major axis and semi-minor axis of the cross-section, `\(A\)` and `\(B\)`, respectively. It is placed on a horizontal ground, with stable equilibrium established. A perturbation is applied to the object to make a small pure rolling oscillation on the ground (without slipping). Find the period of this oscillation given by `\(\omega\)`, with the acceleration due to gravity as `\(g\)`. Assume there are no energy losses, and the only energy input comes from the perturbation.

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
    expected = "`\\( \\omega = \\pi\\sqrt{\\frac{\\left(a^{2}+5b^{2}\\right)b}{g\\left(a^{2}-b^{2}\\right)}}\\)`"
    if normalized == expected:
        result["answer_match"] = 1.0
    return result
```
