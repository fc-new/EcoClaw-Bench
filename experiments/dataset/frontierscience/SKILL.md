---
name: frontierscience
description: Run frontierscience benchmarks to evaluate OpenClaw agent performance across real-world tasks. Use when testing model capabilities, comparing models, submitting benchmark results to the leaderboard, or checking how well your OpenClaw setup handles calendar, email, research, coding, and multi-step workflows.
metadata:
  author: frontierscience
  version: "1.0.0"
---

# Frontierscience Benchmark Skill

Frontierscience measures how well LLM models perform as the brain of an OpenClaw agent. Results are collected on a public leaderboard at [frontierscience.com].

## Prerequisites

- Python 3.10+
- [uv](https://docs.astral.sh/uv/) package manager
- OpenClaw instance (this agent)

## Quick Start

```bash
cd <skill_directory>

# Run benchmark with a specific model
uv run benchmark.py --model anthropic/claude-sonnet-4

# Run only automated tasks (faster)
uv run benchmark.py --model anthropic/claude-sonnet-4 --suite automated-only

# Run specific tasks
uv run benchmark.py --model anthropic/claude-sonnet-4 --suite task_01_calendar,task_02_stock

# Skip uploading results
uv run benchmark.py --model anthropic/claude-sonnet-4 --no-upload
```

## Available Tasks (160)

This skill currently loads all files matching `tasks/task_*.md`, and the repository contains 160 tasks:

- ID range: `task_000_...` to `task_159_...`
- Category: `frontierscience` (all tasks)
- Grading type: `automated` (all tasks)
- Timeout: `300` seconds (all tasks)

Examples from this repository:

| Task ID | Name |
|---------|------|
| `task_000_27c865e6_1c87_489b_b7ea_b197fe3356ba` | Frontierscience physics 000 |
| `task_001_0ea11f5b_df09_4330_92cc_302a63c22008` | Frontierscience physics 001 |
| `task_002_bb0539ef_d9fd_4215_bf16_b0eca44a8778` | Frontierscience physics 002 |
| `task_157_1ca773ca_3f07_4426_8086_d1f3591cdf5f` | Frontierscience biology 157 |
| `task_158_4525a8e7_9e13_47c9_8b87_c0a97ebd355e` | Frontierscience biology 158 |
| `task_159_2f43ac4a_f7e3_46c9_aaee_2f112ff662cb` | Frontierscience biology 159 |

To run a subset, pass full task IDs in `--suite`, for example:

```bash
uv run benchmark.py --model anthropic/claude-sonnet-4 --suite task_000_27c865e6_1c87_489b_b7ea_b197fe3356ba,task_001_0ea11f5b_df09_4330_92cc_302a63c22008
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--model` | Model identifier (e.g., `anthropic/claude-sonnet-4`) |
| `--suite` | `all`, `automated-only`, or comma-separated task IDs |
| `--output-dir` | Results directory (default: `results/`) |
| `--timeout-multiplier` | Scale task timeouts for slower models |
| `--runs` | Number of runs per task for averaging |
| `--parallel` | Number of isolated task runs to execute in parallel |
| `--judge MODEL` | Judge model for LLM grading |
| `--verbose` | Enable verbose logging |
| `--no-upload` | Skip uploading to leaderboard |
| `--register` | Request new API token for submissions |
| `--upload FILE` | Upload previous results JSON |
| `--official-key KEY` | Mark submission as official |

## Token Registration

To submit results to the leaderboard:

```bash
# Register for an API token (one-time)
uv run benchmark.py --register

# Run benchmark (auto-uploads with token)
uv run benchmark.py --model anthropic/claude-sonnet-4

# Run with an official key
uv run benchmark.py --model anthropic/claude-sonnet-4 --official-key your_official_key
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

Create a markdown file in `tasks/` with filename format `task_<index>_<uuid>.md`. Each task needs:

- YAML frontmatter (`id`, `name`, `category`, `grading_type`, `timeout_seconds`)
- Prompt section
- Expected behavior
- Grading criteria
- Automated checks (Python grading function)

## Leaderboard

View results at [frontierscience.com]. The leaderboard shows:

- Model rankings by overall score
- Per-task breakdowns
- Historical performance trends
