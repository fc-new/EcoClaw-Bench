---
name: claw_eval
description: Run claw-eval benchmarks to evaluate OpenClaw agent performance across real-world tasks. Use when testing model capabilities, comparing models, submitting benchmark results to the leaderboard, or checking how well your OpenClaw setup handles calendar, email, research, coding, and multi-step workflows.
metadata:
  author: claw_eval
  version: "1.0.0"
---

# claw-eval Benchmark Skill

claw-eval measures how well LLM models perform as the brain of an OpenClaw agent. Results are collected on a public leaderboard at [claw_eval.com].

## Prerequisites

- Python 3.10+
- [uv](https://docs.astral.sh/uv/) package manager
- OpenClaw instance (this agent)

## Quick Start

```bash
cd <skill_directory>

# Run benchmark with a specific model
uv run scripts/benchmark.py --model anthropic/claude-sonnet-4

# Run all tasks
uv run scripts/benchmark.py --model anthropic/claude-sonnet-4 --suite all

# Run specific tasks by actual task IDs
uv run scripts/benchmark.py --model anthropic/claude-sonnet-4 --suite task_000_t01zh_email_triage,task_071_t72_restaurant_menu_contact

# Skip uploading results
uv run scripts/benchmark.py --model anthropic/claude-sonnet-4 --no-upload
```

## Task Coverage (139)

This dataset is not the old 23-task PinchBench list. It contains **139 real tasks** in `tasks/`, and every task is currently graded as `llm_judge`.

Representative task bands:

| Range | Theme | Examples |
|------|------|---------|
| `task_000`–`task_043` | Office workflows | email triage/reply, calendar scheduling, todo, CRM export, incident/postmortem, operations dashboard |
| `task_044`–`task_070` | Research + engineering analysis | CVE/OSS/regulatory research, finance analysis, code/runtime debugging, paper/comprehension tasks |
| `task_071`–`task_084` | Safety + OfficeQA | prompt/web/email injection defense, table/PDF-based quantitative QA |
| `task_085`–`task_100` | PinchBench-style mixed tasks | planning/writing/memory/file/data tasks, SQLite/WAL recovery, reverse decoding |
| `task_101`–`task_124` | Security + document extraction | XSS filter hardening, schema migration, packet decoding, clock/web tasks, chart/table extraction and reference verification |
| `task_125`–`task_138` | Video multimodal tasks | movie recognition, paper/video understanding, interactive webpage generation, sports QA, subtitle OCR/timestamp and scene analysis |

Category distribution is broad (examples): `finance`, `ops`, `office_qa`, `workflow`, `safety`, `security`, `doc_extraction`, `video_qa`, `video_ocr`, `multimodal_webpage`.

Use this to inspect available tasks:

```bash
ls tasks/task_*.md
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--model` | Model identifier (e.g., `anthropic/claude-sonnet-4`) |
| `--suite` | `all`, `automated-only`, or comma-separated task IDs (`task_000...`) |
| `--output-dir` | Results directory (default: `results/`) |
| `--timeout-multiplier` | Scale task timeouts for slower models |
| `--runs` | Number of runs per task for averaging |
| `--parallel` | Number of isolated task runs to execute in parallel |
| `--judge` | Judge model id (default uses Claude Opus) |
| `--official-key` | Official submission key (or `PINCHBENCH_OFFICIAL_KEY`) |
| `--verbose` / `-v` | Verbose logging |
| `--no-upload` | Skip uploading to leaderboard |
| `--register` | Request new API token for submissions |
| `--upload FILE` | Upload previous results JSON |

## Token Registration

To submit results to the leaderboard:

```bash
# Register for an API token (one-time)
uv run scripts/benchmark.py --register

# Run benchmark (auto-uploads with token)
uv run scripts/benchmark.py --model anthropic/claude-sonnet-4
```

## Results

Results are saved as JSON in the output directory:

```bash
# View task scores
jq '.tasks[] | {task_id, score: .grading.mean}' results/0001_anthropic-claude-sonnet-4.json

# Show failed tasks
jq '.tasks[] | select(.grading.mean < 0.5)' results/*.json

# Calculate overall score
jq '{average: ([.tasks[].grading.mean] | add / length)}' results/*.json
```

## Adding Custom Tasks

Create a markdown file in `tasks/` following `TASK_TEMPLATE.md`. Each task needs:

- YAML frontmatter (id, name, category, grading_type, timeout)
- Prompt section
- Expected behavior
- Grading criteria
- Automated checks (Python grading function)

## Leaderboard

View results at [claw_eval.com]. The leaderboard shows:

- Model rankings by overall score
- Per-task breakdowns
- Historical performance trends
