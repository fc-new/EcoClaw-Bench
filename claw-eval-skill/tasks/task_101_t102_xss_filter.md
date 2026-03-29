---
id: task_101_t102_xss_filter
name: Claw-Eval T102_xss_filter
category: terminal
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/101_00_t102_xss_filter.html
    dest: attack_01.html
  - source: assets/claw_eval/101_01_t102_xss_filter.html
    dest: attack_02.html
  - source: assets/claw_eval/101_02_t102_xss_filter.html
    dest: attack_03.html
  - source: assets/claw_eval/101_03_t102_xss_filter.html
    dest: attack_04.html
  - source: assets/claw_eval/101_04_t102_xss_filter.html
    dest: attack_05.html
  - source: assets/claw_eval/101_05_t102_xss_filter.html
    dest: attack_06.html
  - source: assets/claw_eval/101_06_t102_xss_filter.html
    dest: attack_07.html
  - source: assets/claw_eval/101_07_t102_xss_filter.html
    dest: attack_08.html
  - source: assets/claw_eval/101_08_t102_xss_filter.html
    dest: attack_09.html
  - source: assets/claw_eval/101_09_t102_xss_filter.html
    dest: attack_10.html
  - source: assets/claw_eval/101_10_t102_xss_filter.html
    dest: attack_11.html
  - source: assets/claw_eval/101_11_t102_xss_filter.html
    dest: attack_12.html
  - source: assets/claw_eval/101_12_t102_xss_filter.html
    dest: attack_13.html
  - source: assets/claw_eval/101_13_t102_xss_filter.html
    dest: attack_14.html
  - source: assets/claw_eval/101_14_t102_xss_filter.html
    dest: attack_15.html
  - source: assets/claw_eval/101_15_t102_xss_filter.html
    dest: attack_16.html
  - source: assets/claw_eval/101_16_t102_xss_filter.html
    dest: attack_17.html
  - source: assets/claw_eval/101_17_t102_xss_filter.html
    dest: attack_18.html
  - source: assets/claw_eval/101_18_t102_xss_filter.html
    dest: attack_19.html
  - source: assets/claw_eval/101_19_t102_xss_filter.html
    dest: attack_20.html
  - source: assets/claw_eval/101_20_t102_xss_filter.html
    dest: attack_21.html
  - source: assets/claw_eval/101_21_t102_xss_filter.html
    dest: attack_22.html
  - source: assets/claw_eval/101_22_t102_xss_filter.html
    dest: attack_23.html
  - source: assets/claw_eval/101_23_t102_xss_filter.html
    dest: attack_24.html
  - source: assets/claw_eval/101_24_t102_xss_filter.html
    dest: attack_25.html
  - source: assets/claw_eval/101_25_t102_xss_filter.html
    dest: clean_01.html
  - source: assets/claw_eval/101_26_t102_xss_filter.html
    dest: clean_02.html
  - source: assets/claw_eval/101_27_t102_xss_filter.html
    dest: clean_03.html
  - source: assets/claw_eval/101_28_t102_xss_filter.html
    dest: clean_04.html
  - source: assets/claw_eval/101_29_t102_xss_filter.html
    dest: clean_05.html
  - source: assets/claw_eval/101_30_t102_xss_filter.html
    dest: clean_06.html
  - source: assets/claw_eval/101_31_t102_xss_filter.html
    dest: clean_07.html
  - source: assets/claw_eval/101_32_t102_xss_filter.html
    dest: clean_08.html
  - source: assets/claw_eval/101_33_t102_xss_filter.html
    dest: clean_09.html
  - source: assets/claw_eval/101_34_t102_xss_filter.html
    dest: clean_10.html
  - source: assets/claw_eval/101_35_t102_xss_filter.html
    dest: clean_11.html
  - source: assets/claw_eval/101_36_t102_xss_filter.html
    dest: clean_12.html
---

## Prompt

Container files:

- /workspace/fixtures/samples/ — directory with 37 HTML files
  - attack_01.html through attack_25.html — HTML files with various XSS attack vectors
  - clean_01.html through clean_12.html — benign HTML files with legitimate structure

Write /workspace/filter.py that takes an HTML file path as its first
command-line argument and sanitizes the file IN-PLACE, removing all
JavaScript and XSS attack vectors while preserving legitimate HTML
structure and content.

Usage: python /workspace/filter.py <path_to_html_file>

Requirements:
1. Remove all XSS vectors including: script tags, event handlers (on*
   attributes), javascript: URLs, data: URLs with scripts, SVG/MathML
   script injection, meta refresh to javascript, CSS expressions,
   dangerous embed/object/iframe elements, form actions with javascript
2. Handle encoded payloads: HTML entities, URL encoding, mixed case
3. Preserve legitimate HTML structure: headings, paragraphs, lists,
   tables, images with safe src, links with safe href, safe inline styles
4. The filter must work with Python's standard library only (no pip
   packages available in the container)
5. Exit code 0 on success

The attack files contain diverse XSS vectors. Your filter will be
tested against all 37 files — it must block attacks while keeping
clean files intact.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T102_xss_filter`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

rule-based
