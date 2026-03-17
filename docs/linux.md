# Linux/macOS Guide

Use this guide when running large-scale experiments on Linux/macOS.

## 1) Prerequisites

- Python 3.10+
- `uv`
- `openclaw` CLI available in `PATH`
- Running OpenClaw/EcoClaw runtime

## 2) Environment

From repo root:

```bash
cp .env.example .env
```

Set at least:

```env
ECOCLAW_API_KEY=sk-xxx
ECOCLAW_BASE_URL=https://concept.dica.cc/llm
ECOCLAW_MODEL=claude-haiku-4.5
ECOCLAW_JUDGE=gpt-5-nano
```

If PinchBench `skill` is not at `../skill` or `~/skill`, set:

```env
ECOCLAW_SKILL_DIR=/absolute/path/to/skill
```

## 3) Run

```bash
chmod +x experiments/scripts/*.sh
```

Single-task sanity check:

```bash
./experiments/scripts/run_pinchbench_baseline.sh --suite task_00_sanity --runs 1
./experiments/scripts/run_pinchbench_ecoclaw.sh --suite task_00_sanity --runs 1
```

Full automated suite:

```bash
./experiments/scripts/run_pinchbench_baseline.sh --suite automated-only --runs 1
./experiments/scripts/run_pinchbench_ecoclaw.sh --suite automated-only --runs 1
```

Compare:

```bash
./experiments/scripts/compare_pinchbench_results.sh
```

Report output:

- `results/reports/pinchbench_comparison.json`
