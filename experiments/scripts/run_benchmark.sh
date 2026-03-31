#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

import_dotenv() {
  local env_path="${1:-${REPO_ROOT}/.env}"
  if [[ ! -f "${env_path}" ]]; then
    return 0
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "${line}" ]] && continue
    [[ "${line}" == \#* ]] && continue
    [[ "${line}" != *=* ]] && continue
    local key="${line%%=*}"
    local value="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    export "${key}=${value}"
  done < "${env_path}"
}

resolve_model_alias() {
  local model_like="${1:?model alias is required}"
  local openai_provider_prefix="${ECOCLAW_OPENAI_PROVIDER:-dica}"
  if [[ "${model_like}" == */* ]]; then
    printf '%s\n' "${model_like}"
    return 0
  fi

  case "${model_like}" in
    gpt-oss-20b) printf '%s/gpt-oss-20b\n' "${openai_provider_prefix}" ;;
    gpt-oss-120b) printf '%s/gpt-oss-120b\n' "${openai_provider_prefix}" ;;
    gpt-5-nano) printf '%s/gpt-5-nano\n' "${openai_provider_prefix}" ;;
    gpt-5-mini) printf '%s/gpt-5-mini\n' "${openai_provider_prefix}" ;;
    gpt-5) printf '%s/gpt-5\n' "${openai_provider_prefix}" ;;
    gpt-5-chat) printf '%s/gpt-5-chat\n' "${openai_provider_prefix}" ;;
    gpt-4.1-nano) printf '%s/gpt-4.1-nano\n' "${openai_provider_prefix}" ;;
    gpt-4.1-mini) printf '%s/gpt-4.1-mini\n' "${openai_provider_prefix}" ;;
    gpt-4.1) printf '%s/gpt-4.1\n' "${openai_provider_prefix}" ;;
    gpt-4o-mini) printf '%s/gpt-4o-mini\n' "${openai_provider_prefix}" ;;
    gpt-4o) printf '%s/gpt-4o\n' "${openai_provider_prefix}" ;;
    o1) printf '%s/o1\n' "${openai_provider_prefix}" ;;
    o1-mini) printf '%s/o1-mini\n' "${openai_provider_prefix}" ;;
    o1-pro) printf '%s/o1-pro\n' "${openai_provider_prefix}" ;;
    o3-mini) printf '%s/o3-mini\n' "${openai_provider_prefix}" ;;
    o3) printf '%s/o3\n' "${openai_provider_prefix}" ;;
    o4-mini) printf '%s/o4-mini\n' "${openai_provider_prefix}" ;;
    claude-3.5-sonnet) printf 'openrouter/anthropic/claude-3.5-sonnet\n' ;;
    claude-3.5-haiku) printf 'openrouter/anthropic/claude-3.5-haiku\n' ;;
    claude-3.7-sonnet) printf 'openrouter/anthropic/claude-3.7-sonnet\n' ;;
    claude-sonnet-4) printf 'openrouter/anthropic/claude-sonnet-4\n' ;;
    claude-opus-4.1) printf 'openrouter/anthropic/claude-opus-4.1\n' ;;
    claude-haiku-4.5) printf 'openrouter/anthropic/claude-haiku-4.5\n' ;;
    *)
      printf 'Unknown model alias: %s\n' "${model_like}" >&2
      return 1
      ;;
  esac
}

apply_ecoclaw_env() {
  if [[ -n "${ECOCLAW_API_KEY:-}" ]]; then
    export OPENAI_API_KEY="${ECOCLAW_API_KEY}"
    export OPENROUTER_API_KEY="${ECOCLAW_API_KEY}"
  fi
  if [[ -n "${ECOCLAW_BASE_URL:-}" ]]; then
    export OPENAI_BASE_URL="${ECOCLAW_BASE_URL}"
    export OPENROUTER_BASE_URL="${ECOCLAW_BASE_URL}"
  fi
}

resolve_skill_dir() {
  if [[ -n "${ECOCLAW_SKILL_DIR:-}" && -d "${ECOCLAW_SKILL_DIR}" ]]; then
    printf '%s\n' "${ECOCLAW_SKILL_DIR}"
    return 0
  fi
  if [[ -d "${REPO_ROOT}/../skill" ]]; then
    printf '%s\n' "${REPO_ROOT}/../skill"
    return 0
  fi
  if [[ -d "${HOME}/skill" ]]; then
    printf '%s\n' "${HOME}/skill"
    return 0
  fi
  printf 'PinchBench skill directory not found. Set ECOCLAW_SKILL_DIR in .env\n' >&2
  return 1
}

latest_json_in_dir() {
  local dir_path="${1:?directory path is required}"
  if [[ ! -d "${dir_path}" ]]; then
    return 1
  fi
  local latest_file
  latest_file="$(python - <<'PY' "${dir_path}"
import pathlib
import sys

dir_path = pathlib.Path(sys.argv[1])
files = sorted(dir_path.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
print(files[0] if files else "")
PY
)"
  if [[ -z "${latest_file}" ]]; then
    return 1
  fi
  printf '%s\n' "${latest_file}"
}

generate_cost_report_and_print_summary() {
  local result_json="${1:?result json is required}"
  local report_json="${2:?report json is required}"
  local cache_write_ttl="${ECOCLAW_CACHE_WRITE_TTL:-5m}"

  if [[ ! -f "${result_json}" ]]; then
    echo "Cost report skipped: result file not found: ${result_json}" >&2
    return 0
  fi

  if ! python "${REPO_ROOT}/src/cost/calculate_llm_cost.py" \
    --input "${result_json}" \
    --output "${report_json}" \
    --cache-write-ttl "${cache_write_ttl}" >/dev/null; then
    echo "Cost report generation failed for ${result_json}" >&2
    return 0
  fi

  python - <<'PY' "${report_json}"
import json
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
data = json.loads(report_path.read_text(encoding="utf-8"))
totals = data.get("totals", {})
by_model = data.get("by_model", [])

print("=" * 80)
print("COST SUMMARY")
print("=" * 80)
print(f"Report: {report_path}")
print(f"Total cost: ${totals.get('cost_usd', 0.0):.6f} (¥{totals.get('cost_cny', 0.0):.6f})")
print(f"Requests priced: {totals.get('priced_requests', 0)}/{totals.get('requests', 0)}")
if by_model:
    print("-" * 80)
    print(f"{'MODEL':42} {'COST_USD':>12} {'COST_CNY':>12} {'REQUESTS':>10}")
    print("-" * 80)
    for row in by_model:
        model = str(row.get("model", "unknown"))[:42]
        print(
            f"{model:42} "
            f"{float(row.get('cost_usd', 0.0)):12.6f} "
            f"{float(row.get('cost_cny', 0.0)):12.6f} "
            f"{int(row.get('requests', 0)):10d}"
        )
print("=" * 80)
PY
}

MODEL=""
JUDGE=""
SUITE=""
RUNS=""
TIMEOUT_MULTIPLIER=""
PARALLEL=""
BENCHMARK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="${2:-}"; shift 2 ;;
    --judge) JUDGE="${2:-}"; shift 2 ;;
    --suite) SUITE="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --timeout-multiplier) TIMEOUT_MULTIPLIER="${2:-}"; shift 2 ;;
    --parallel) PARALLEL="${2:-}"; shift 2 ;;
    --benchmark) BENCHMARK="${2:-}"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

import_dotenv
apply_ecoclaw_env

BENCHMARK_LIKE="${BENCHMARK:-${ECOCLAW_BENCHMARK:-claw_eval}}"
case "${BENCHMARK_LIKE}" in
  claw_eval|claw-eval)
    BENCHMARK_ID="claw_eval"
    SKILL_SOURCE_DEFAULT="${REPO_ROOT}/claw-eval-skill"
    OUTPUT_DIR="${REPO_ROOT}/results/raw/claw_eval/ecoclaw"
    RUN_LOG_PREFIX="claw_eval_ecoclaw"
    COST_REPORT_PREFIX="claw_eval_ecoclaw"
    ;;
  frontierscience|frontier-science|frontier_science)
    BENCHMARK_ID="frontierscience"
    SKILL_SOURCE_DEFAULT="${REPO_ROOT}/frontierscience-skill"
    OUTPUT_DIR="${REPO_ROOT}/results/raw/frontierscience/ecoclaw"
    RUN_LOG_PREFIX="frontierscience_ecoclaw"
    COST_REPORT_PREFIX="frontierscience_ecoclaw"
    ;;
  pinchbench|pinch-bench|pinch_bench)
    BENCHMARK_ID="pinchbench"
    SKILL_SOURCE_DEFAULT="${REPO_ROOT}/skill-xubqpanda"
    OUTPUT_DIR="${REPO_ROOT}/results/raw/pinchbench/ecoclaw"
    RUN_LOG_PREFIX="pinchbench_ecoclaw"
    COST_REPORT_PREFIX="ecoclaw"
    ;;
  *)
    echo "Unknown benchmark: ${BENCHMARK_LIKE}" >&2
    exit 1
    ;;
esac

DATASET_ROOT="${REPO_ROOT}/experiments/dataset"
DATASET_LINK="${DATASET_ROOT}/${BENCHMARK_ID}"
SKILL_SOURCE="${ECOCLAW_SKILL_DIR:-${SKILL_SOURCE_DEFAULT}}"

mkdir -p "${DATASET_ROOT}"
ln -sfn "${SKILL_SOURCE}" "${DATASET_LINK}"
export ECOCLAW_SKILL_DIR="${DATASET_LINK}"

MODEL_LIKE="${MODEL:-${ECOCLAW_MODEL:-gmn/gpt-5.4}}"
JUDGE_LIKE="${JUDGE:-${ECOCLAW_JUDGE:-gmn/gpt-5.4}}"
RESOLVED_MODEL="$(resolve_model_alias "${MODEL_LIKE}")"
RESOLVED_JUDGE="$(resolve_model_alias "${JUDGE_LIKE}")"
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-all}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-1}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"
RESOLVED_PARALLEL="${PARALLEL:-${ECOCLAW_PARALLEL:-4}}"

LOG_DIR="${REPO_ROOT}/log"
RUN_TAG="$(date +%Y%m%d_%H%M%S)"
RUN_LOG_FILE="${LOG_DIR}/${RUN_LOG_PREFIX}_${RUN_TAG}.log"
BENCHMARK_LOG_FILE="${LOG_DIR}/${RUN_LOG_PREFIX}_${RUN_TAG}_benchmark.log"
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

SKILL_DIR="$(resolve_skill_dir)"
cd "${SKILL_DIR}"

PARALLEL_ARGS=()
if uv run scripts/benchmark.py --help 2>/dev/null | grep -q -- "--parallel"; then
  PARALLEL_ARGS=(--parallel "${RESOLVED_PARALLEL}")
elif [[ "${RESOLVED_PARALLEL}" != "1" ]]; then
  echo "Current benchmark.py does not support --parallel, but requested parallel=${RESOLVED_PARALLEL}" >&2
  exit 1
fi

uv run scripts/benchmark.py \
  --model "${RESOLVED_MODEL}" \
  --judge "${RESOLVED_JUDGE}" \
  --suite "${RESOLVED_SUITE}" \
  --runs "${RESOLVED_RUNS}" \
  "${PARALLEL_ARGS[@]}" \
  --timeout-multiplier "${RESOLVED_TIMEOUT}" \
  --output-dir "${OUTPUT_DIR}" \
  --no-upload \
  2>&1 | tee "${RUN_LOG_FILE}"

if [[ -f "${SKILL_DIR}/benchmark.log" ]]; then
  cp "${SKILL_DIR}/benchmark.log" "${BENCHMARK_LOG_FILE}"
fi

echo "Run log saved to: ${RUN_LOG_FILE}"
if [[ -f "${BENCHMARK_LOG_FILE}" ]]; then
  echo "Benchmark log saved to: ${BENCHMARK_LOG_FILE}"
fi

RESULT_JSON="$(latest_json_in_dir "${OUTPUT_DIR}" || true)"
if [[ -n "${RESULT_JSON}" ]]; then
  COST_REPORT_DIR="${REPO_ROOT}/results/reports"
  COST_REPORT_FILE="${COST_REPORT_DIR}/${COST_REPORT_PREFIX}_${RUN_TAG}_cost.json"
  mkdir -p "${COST_REPORT_DIR}"
  generate_cost_report_and_print_summary "${RESULT_JSON}" "${COST_REPORT_FILE}"
else
  echo "Cost report skipped: no result JSON found in ${OUTPUT_DIR}" >&2
fi
