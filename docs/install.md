# Installation Guide

## 1) Clone required repositories

```bash
git clone https://github.com/Xubqpanda/EcoClaw.git
git clone https://github.com/pinchbench/skill.git
git clone https://github.com/Xubqpanda/EcoClaw-Bench.git
```

## 2) Install prerequisites

- Python 3.10+
- `uv` package manager
- OpenClaw/EcoClaw runtime dependencies

PinchBench side:

```bash
cd skill
uv sync
```

EcoClaw side:

```bash
cd EcoClaw
npm install
```

## 3) Start OpenClaw/EcoClaw runtime

Use your normal OpenClaw startup command and ensure the agent endpoint is reachable before running benchmarks.

## 4) Configure environment

```bash
cd EcoClaw-Bench
cp .env.example .env
```

Then edit `.env` and fill your values:

- `ECOCLAW_API_KEY`
- `ECOCLAW_BASE_URL`
- `ECOCLAW_MODEL`
- `ECOCLAW_JUDGE`

See [env.md](env.md) for details.

## 5) Run benchmark scripts

Windows (PowerShell):

```powershell
.\experiments\scripts\run_pinchbench_baseline.ps1
.\experiments\scripts\run_pinchbench_ecoclaw.ps1
.\experiments\scripts\compare_pinchbench_results.ps1
```

Linux/macOS (bash):

```bash
chmod +x experiments/scripts/*.sh
./experiments/scripts/run_pinchbench_baseline.sh
./experiments/scripts/run_pinchbench_ecoclaw.sh
./experiments/scripts/compare_pinchbench_results.sh
```
