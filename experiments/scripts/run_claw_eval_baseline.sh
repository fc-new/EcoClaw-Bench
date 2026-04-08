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
PARALLEL=""
ENABLE_MULTI_AGENT=0
MULTI_AGENT_ROLES=""
AGENT_CONFIG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="${2:-}"; shift 2 ;;
    --judge) JUDGE="${2:-}"; shift 2 ;;
    --suite) SUITE="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --timeout-multiplier) TIMEOUT_MULTIPLIER="${2:-}"; shift 2 ;;
    --parallel) PARALLEL="${2:-}"; shift 2 ;;
    --enable-multi-agent) ENABLE_MULTI_AGENT=1; shift ;;
    --multi-agent-roles) MULTI_AGENT_ROLES="${2:-}"; shift 2 ;;
    --agent-config) AGENT_CONFIG="${2:-}"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

import_dotenv
apply_ecoclaw_env
ensure_openclaw_gateway_running
recover_stale_openclaw_config_backup

ECOCLAW_WAS_ENABLED=0
if openclaw plugins list 2>/dev/null | grep -qE '│ EcoClaw[[:space:]]+│ ecoclaw[[:space:]]+│ loaded[[:space:]]+│'; then
  ECOCLAW_WAS_ENABLED=1
fi

restore_ecoclaw_plugin() {
  if [[ "${ECOCLAW_WAS_ENABLED}" == "1" ]]; then
    openclaw plugins enable ecoclaw >/dev/null 2>&1 || true
  fi
}

trap restore_ecoclaw_plugin EXIT

openclaw plugins disable ecoclaw >/dev/null 2>&1 || true

if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/claw-eval-skill" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/claw-eval-skill"
fi
if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/experiments/dataset/claw_eval" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/experiments/dataset/claw_eval"
fi

MODEL_LIKE="${MODEL:-${ECOCLAW_MODEL:-tuzi/gpt-5.4}}"
JUDGE_LIKE="${JUDGE:-${ECOCLAW_JUDGE:-tuzi/gpt-5.4}}"
RESOLVED_MODEL="$(resolve_model_alias "${MODEL_LIKE}")"
RESOLVED_JUDGE="$(resolve_model_alias "${JUDGE_LIKE}")"
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-all}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-1}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"
RESOLVED_PARALLEL="${PARALLEL:-${ECOCLAW_PARALLEL:-4}}"

# Multi-agent: resolve from CLI flag or env var
if [[ "${ENABLE_MULTI_AGENT}" == "0" ]] && [[ "${ECOCLAW_ENABLE_MULTI_AGENT:-false}" =~ ^(true|1|yes)$ ]]; then
  ENABLE_MULTI_AGENT=1
fi
RESOLVED_MULTI_AGENT_ROLES="${MULTI_AGENT_ROLES:-${ECOCLAW_MULTI_AGENT_ROLES:-coder,researcher,reviewer}}"
RESOLVED_AGENT_CONFIG="${AGENT_CONFIG:-${ECOCLAW_AGENT_CONFIG:-}}"

# Resolve to absolute path early (before any cd)
if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
  RESOLVED_AGENT_CONFIG="$(cd "$(dirname "${RESOLVED_AGENT_CONFIG}")" && pwd)/$(basename "${RESOLVED_AGENT_CONFIG}")"
fi

# If an agent config is provided, force multi-agent on
if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
  ENABLE_MULTI_AGENT=1
fi

if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
  OUTPUT_DIR="${REPO_ROOT}/results/raw/claw_eval/multi_agent"
else
  OUTPUT_DIR="${REPO_ROOT}/results/raw/claw_eval/baseline"
fi
LOG_DIR="${REPO_ROOT}/log"
RUN_TAG="$(date +%Y%m%d_%H%M%S)"
RUN_LOG_FILE="${LOG_DIR}/claw_eval_baseline_${RUN_TAG}.log"
BENCHMARK_LOG_FILE="${LOG_DIR}/claw_eval_baseline_${RUN_TAG}_benchmark.log"
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

# Multi-agent config injection
if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
  backup_openclaw_config
  if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
    AGENT_CONFIG_DIR="$(cd "$(dirname "${RESOLVED_AGENT_CONFIG}")" && pwd)"
    SKILLS_DIR="${AGENT_CONFIG_DIR}/../skills"
    if [[ -d "${SKILLS_DIR}" ]]; then
      SKILLS_DIR="$(cd "${SKILLS_DIR}" && pwd)"
    else
      SKILLS_DIR=""
    fi
    inject_agent_config_from_file "${RESOLVED_AGENT_CONFIG}" "${SKILLS_DIR}"
  else
    RESOLVED_SUBAGENT_THINKING="${ECOCLAW_SUBAGENT_THINKING:-medium}"
    RESOLVED_SUBAGENT_MAX_CONCURRENT="${ECOCLAW_SUBAGENT_MAX_CONCURRENT:-4}"
    inject_multi_agent_config "${RESOLVED_MODEL}" "${RESOLVED_SUBAGENT_THINKING}" "${RESOLVED_SUBAGENT_MAX_CONCURRENT}"
  fi
fi

# Ensure config is restored on exit (multi-agent) while also restoring ecoclaw plugin
restore_ecoclaw_plugin() {
  if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
    restore_openclaw_config || true
  fi
  if [[ "${ECOCLAW_WAS_ENABLED}" == "1" ]]; then
    openclaw plugins enable ecoclaw >/dev/null 2>&1 || true
  fi
}
trap restore_ecoclaw_plugin EXIT

# Build benchmark.py arguments
BENCH_ARGS=(
  --model "${RESOLVED_MODEL}"
  --judge "${RESOLVED_JUDGE}"
  --suite "${RESOLVED_SUITE}"
  --runs "${RESOLVED_RUNS}"
  --parallel "${RESOLVED_PARALLEL}"
  --timeout-multiplier "${RESOLVED_TIMEOUT}"
  --output-dir "${OUTPUT_DIR}"
  --no-upload
)
if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
  BENCH_ARGS+=(--enable-multi-agent)
  if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
    BENCH_ARGS+=(--agent-config "${RESOLVED_AGENT_CONFIG}")
  else
    BENCH_ARGS+=(--multi-agent-roles "${RESOLVED_MULTI_AGENT_ROLES}")
  fi
fi

SKILL_DIR="$(resolve_skill_dir)"
cd "${SKILL_DIR}"
uv run scripts/benchmark.py "${BENCH_ARGS[@]}" \
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
  COST_REPORT_FILE="${COST_REPORT_DIR}/claw_eval_baseline_${RUN_TAG}_cost.json"
  mkdir -p "${COST_REPORT_DIR}"
  generate_cost_report_and_print_summary "${RESULT_JSON}" "${COST_REPORT_FILE}"
else
  echo "Cost report skipped: no result JSON found in ${OUTPUT_DIR}" >&2
fi
