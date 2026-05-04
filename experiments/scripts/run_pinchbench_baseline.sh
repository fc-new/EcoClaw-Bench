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
SESSION_MODE=""
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
    --session-mode) SESSION_MODE="${2:-}"; shift 2 ;;
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
recover_stale_openclaw_config_backup

configure_baseline_runtime() {
  local config_path="${OPENCLAW_CONFIG_PATH:-${HOME}/.openclaw/openclaw.json}"
  if [[ ! -f "${config_path}" ]]; then
    echo "WARN: openclaw config not found, skip baseline runtime patch: ${config_path}" >&2
    return 0
  fi
  python3 - "${config_path}" <<'BASELINE_PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
obj = json.loads(config_path.read_text(encoding="utf-8"))
plugins = obj.setdefault("plugins", {})
entries = plugins.setdefault("entries", {})
slots = plugins.setdefault("slots", {})
eco = entries.setdefault("ecoclaw", {})
eco["enabled"] = False
slots["contextEngine"] = "legacy"
config_path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
BASELINE_PY
}

if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/pinchbench-skill" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/pinchbench-skill"
fi
if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/experiments/dataset/pinchbench" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/experiments/dataset/pinchbench"
fi

backup_openclaw_config
configure_baseline_runtime
validate_openclaw_runtime_config
ECOCLAW_FORCE_GATEWAY_RESTART=true ensure_openclaw_gateway_running

MODEL_LIKE="${MODEL:-${BASELINE_MODEL:-gpt-5.4-mini}}"
JUDGE_LIKE="${JUDGE:-${BASELINE_JUDGE:-gpt-5.4-mini}}"
RESOLVED_MODEL="$(resolve_model_alias "${MODEL_LIKE}")"
RESOLVED_JUDGE="$(resolve_model_alias "${JUDGE_LIKE}")"
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-automated-only}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-3}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"
RESOLVED_PARALLEL="${PARALLEL:-${ECOCLAW_PARALLEL:-1}}"
RESOLVED_SESSION_MODE="${SESSION_MODE:-${ECOCLAW_SESSION_MODE:-isolated}}"

# Multi-agent: resolve from CLI flag or env var
if [[ "${ENABLE_MULTI_AGENT}" == "0" ]] && [[ "${ECOCLAW_ENABLE_MULTI_AGENT:-false}" =~ ^(true|1|yes)$ ]]; then
  ENABLE_MULTI_AGENT=1
fi
RESOLVED_MULTI_AGENT_ROLES="${MULTI_AGENT_ROLES:-${ECOCLAW_MULTI_AGENT_ROLES:-researcher,coder}}"
RESOLVED_AGENT_CONFIG="${AGENT_CONFIG:-${ECOCLAW_AGENT_CONFIG:-}}"

# If an agent config is provided, force multi-agent on
if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
  ENABLE_MULTI_AGENT=1
fi

if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
  OUTPUT_DIR="${REPO_ROOT}/results/raw/pinchbench/multi_agent"
else
  OUTPUT_DIR="${REPO_ROOT}/results/raw/pinchbench/baseline"
fi
LOG_DIR="${REPO_ROOT}/log"
RUN_TAG="$(date +%Y%m%d_%H%M%S)"
RUN_LOG_FILE="${LOG_DIR}/pinchbench_baseline_${RUN_TAG}.log"
BENCHMARK_LOG_FILE="${LOG_DIR}/pinchbench_baseline_${RUN_TAG}_benchmark.log"
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

# Ensure config is restored on exit
restore_baseline_runtime() {
  if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
    restore_openclaw_config || true
  else
    restore_openclaw_config || true
  fi
  ECOCLAW_FORCE_GATEWAY_RESTART=true ensure_openclaw_gateway_running >/dev/null 2>&1 || true
}
trap restore_baseline_runtime EXIT

# Build benchmark.py arguments
BENCH_ARGS=(
  --model "${RESOLVED_MODEL}"
  --judge "${RESOLVED_JUDGE}"
  --suite "${RESOLVED_SUITE}"
  --runs "${RESOLVED_RUNS}"
  --parallel "${RESOLVED_PARALLEL}"
  --session-mode "${RESOLVED_SESSION_MODE}"
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
  COST_REPORT_FILE="${COST_REPORT_DIR}/baseline_${RUN_TAG}_cost.json"
  mkdir -p "${COST_REPORT_DIR}"
  generate_cost_report_and_print_summary "${RESULT_JSON}" "${COST_REPORT_FILE}"
else
  echo "Cost report skipped: no result JSON found in ${OUTPUT_DIR}" >&2
fi
