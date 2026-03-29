---
id: task_046_4f1cf869_3ea3_400c_8fa3_e4d3f6fe1cdf
name: Frontierscience physics 046
category: frontierscience
grading_type: automated
timeout_seconds: 300
workspace_files: []
---

## Prompt

Two uniform balls of radius `\(r\)` and density `\(ρ\)` are in contact with each other, and they revolve around a uniform ball of radius `\(R_0\)` and density `\(ρ_M\)` with the same angular velocity. The centers of the three balls remain collinear, and the orbit of the revolution is circular. Suppose `\(ρ_M R_0^3≫ρr^3\)` and the distance between the point of contact of the two small spheres and the center of the large sphere `\(R \gg r\)`. We can assume that the large ball is not moving at all due to its huge mass. The only force of interaction between the bodies that we consider here is gravity. Find the critical value for `\( R \)` denoted as `\( R_C \)` such that the two small balls keep in touch. Express your answer in terms of the constants defined above.

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
    expected = "`\\(r_c=r_0 \\left(\\frac{12 \\ρ_m}{\\ρ} \\right)^{1/3}\\)`"
    if normalized == expected:
        result["answer_match"] = 1.0
    return result
```
