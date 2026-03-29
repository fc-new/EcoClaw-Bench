---
id: task_024_d1cec1fb_13bb_475a_b2f1_956db5ef3b77
name: Frontierscience physics 024
category: frontierscience
grading_type: automated
timeout_seconds: 300
workspace_files: []
---

## Prompt

Consider two atoms separated by a distance `\( R \)`. Since they are electrically neutral, there is no force between them in the absence of perturbations. However, if one of the atoms is slightly polarized, a very weak attractive force emerges between the two atoms. Here, we assume that both atoms consist of a positively charged nucleus `\( (+e) \)` fixed in place (the distance `\( R \)` is the inter-nuclear distance)  and an electron `\( (-e) \)` with mass `\( m \)`, connected to the nucleus by springs with spring constant `\( k \)`.  We further assume that the electrons are constrained to move along the line connecting the two nuclei, with displacements `\( x_1 \)` and `\( x_2 \)`, respectively. Thus, the elastic potential energy of the two springs can be written as `\( \frac{1}{2} kx_1^2 \)` and `\( \frac{1}{2} kx_2^2 \)`, respectively.

Under the condition that both `\( \left|x_{1}\right| \)` and `\( \left|x_{2}\right| \)` are much smaller than `\( R \)`, find the Coulomb electrostatic potential energy `\( U \)`of this system in terms of \(e, x_1, x_2, \epsilon_0, R\), where \(\epsilon_0 \) is the electric vacuum permittivity.

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
    expected = "`\\( u=-\\frac{e^2x_1x_2}{2\\pi\\varepsilon_0 r^3} \\) `"
    if normalized == expected:
        result["answer_match"] = 1.0
    return result
```
