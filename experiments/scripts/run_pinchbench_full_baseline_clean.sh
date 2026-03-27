#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

MODEL="${MODEL:-gmn/gpt-5.4}"
JUDGE="${JUDGE:-gmn/gpt-5.4}"
RUNS="${RUNS:-1}"
PARALLEL="${PARALLEL:-1}"
TIMEOUT_MULTIPLIER="${TIMEOUT_MULTIPLIER:-1.0}"

import_dotenv
apply_ecoclaw_env

SKILL_DIR="$(resolve_skill_dir)"
SUITE="$(cd "${SKILL_DIR}" && ls -1 tasks/task_*.md | sed 's#.*/##' | sed 's#.md$##' | grep -v '^TASK_TEMPLATE$' | sort | paste -sd, -)"

echo "[baseline-full] suite=${SUITE}"
echo "[baseline-full] disabling ecoclaw plugin for clean baseline..."
openclaw plugins disable ecoclaw >/dev/null 2>&1 || true

"${SCRIPT_DIR}/run_pinchbench_baseline.sh" \
  --model "${MODEL}" \
  --judge "${JUDGE}" \
  --suite "${SUITE}" \
  --runs "${RUNS}" \
  --parallel "${PARALLEL}" \
  --timeout-multiplier "${TIMEOUT_MULTIPLIER}"

echo "[baseline-full] done."
