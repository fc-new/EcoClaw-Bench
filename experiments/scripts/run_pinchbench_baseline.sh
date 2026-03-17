#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

MODEL=""
JUDGE=""
SUITE=""
RUNS=""
TIMEOUT_MULTIPLIER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="${2:-}"; shift 2 ;;
    --judge) JUDGE="${2:-}"; shift 2 ;;
    --suite) SUITE="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --timeout-multiplier) TIMEOUT_MULTIPLIER="${2:-}"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

import_dotenv
apply_ecoclaw_env

MODEL_LIKE="${MODEL:-${ECOCLAW_MODEL:-claude-sonnet-4}}"
JUDGE_LIKE="${JUDGE:-${ECOCLAW_JUDGE:-claude-opus-4.1}}"
RESOLVED_MODEL="$(resolve_model_alias "${MODEL_LIKE}")"
RESOLVED_JUDGE="$(resolve_model_alias "${JUDGE_LIKE}")"
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-automated-only}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-3}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"

OUTPUT_DIR="${REPO_ROOT}/results/raw/pinchbench/baseline"
mkdir -p "${OUTPUT_DIR}"

SKILL_DIR="$(resolve_skill_dir)"
cd "${SKILL_DIR}"
uv run scripts/benchmark.py \
  --model "${RESOLVED_MODEL}" \
  --judge "${RESOLVED_JUDGE}" \
  --suite "${RESOLVED_SUITE}" \
  --runs "${RESOLVED_RUNS}" \
  --timeout-multiplier "${RESOLVED_TIMEOUT}" \
  --output-dir "${OUTPUT_DIR}" \
  --no-upload
