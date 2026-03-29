---
id: task_014_e2bef5ee_c2ee_4704_b52a_63bb2e7aea7a
name: Frontierscience physics 014
category: frontierscience
grading_type: automated
timeout_seconds: 300
workspace_files: []
---

## Prompt

A certain region of space has an electric potential \\(V\\) which is cylindrically symmetrical about the \\(z \\)-axis and can be written as \\(V (\\rho, z) \\) , with \\(\\rho \\) the distance from the \\( z \\)-axis. The setup also includes a uniform magnetic field `\(\vec B = B \hat{z} \)` pointing along the `\( z \)-`direction. Gravity can be ignored.\
\
A particle with positive charge \\(q &gt; 0\\) and mass \\( m\\) is released in this potential. We want the potential to be such that there exists a maximum distance from the origin that the particle will ever reach. The potential and magnetic field must satisfy Maxwell's equations in free space.

The potential does not include the potential from the particle itself. We ignore radiation by the particle.

We assume the potential is at most quadratic, of the form\
\\(V(\\rho, z) = a + b \\rho + c z + d \\rho^2 + e z^2\\)\
for some constants \\(a, b, c, d\), and \\(e\).\
\
We also want a charged particle released from rest at the origin to remain at the origin. We drop the constant term in the potential, so \\(a = 0\\).\
\
There are three possible motions of the particle that are motions with a single angular frequency. Find an equation for \\( \\omega\_{\\rm sum}\\) the sum of these three angular frequencies. Give your answer in terms of \\(B, e, q, \\) and \\( m\\).

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
    expected = "\\\\(\\\\omega\\_{\\\\rm sum} = \\\\frac{qb}{m} + \\\\sqrt{ \\\\frac{2qe}{m} } \\\\)"
    if normalized == expected:
        result["answer_match"] = 1.0
    return result
```
