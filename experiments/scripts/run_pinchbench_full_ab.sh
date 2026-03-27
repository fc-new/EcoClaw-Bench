#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASELINE_MODEL="${BASELINE_MODEL:-gmn/gpt-5.4}"
ECOCLAW_MODEL="${ECOCLAW_MODEL:-ecoclaw/gpt-5.4}"
JUDGE="${JUDGE:-gmn/gpt-5.4}"
RUNS="${RUNS:-1}"
PARALLEL="${PARALLEL:-1}"
TIMEOUT_MULTIPLIER="${TIMEOUT_MULTIPLIER:-1.0}"

echo "[full-ab] step 1/2: baseline full run"
MODEL="${BASELINE_MODEL}" JUDGE="${JUDGE}" RUNS="${RUNS}" PARALLEL="${PARALLEL}" TIMEOUT_MULTIPLIER="${TIMEOUT_MULTIPLIER}" \
  "${SCRIPT_DIR}/run_pinchbench_full_baseline_clean.sh"

echo "[full-ab] step 2/2: ecoclaw full run"
MODEL="${ECOCLAW_MODEL}" JUDGE="${JUDGE}" RUNS="${RUNS}" PARALLEL="${PARALLEL}" TIMEOUT_MULTIPLIER="${TIMEOUT_MULTIPLIER}" \
  "${SCRIPT_DIR}/run_pinchbench_full_ecoclaw.sh"

echo "[full-ab] all done."
