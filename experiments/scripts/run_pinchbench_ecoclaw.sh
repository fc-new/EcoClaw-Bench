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
export ECOCLAW_FORCE_GATEWAY_RESTART="${ECOCLAW_FORCE_GATEWAY_RESTART:-true}"
recover_stale_openclaw_config_backup
ensure_ecoclaw_plugin_config
ensure_openclaw_gateway_running

if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/pinchbench-skill" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/pinchbench-skill"
fi
if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/experiments/dataset/pinchbench" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/experiments/dataset/pinchbench"
fi

MODEL_LIKE="${MODEL:-${ECOCLAW_MODEL:-tuzi/gpt-5.4}}"
JUDGE_LIKE="${JUDGE:-${ECOCLAW_JUDGE:-tuzi/gpt-5.4}}"
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

# Resolve to absolute path early (before any cd)
if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
  RESOLVED_AGENT_CONFIG="$(cd "$(dirname "${RESOLVED_AGENT_CONFIG}")" && pwd)/$(basename "${RESOLVED_AGENT_CONFIG}")"
fi

# If an agent config is provided, force multi-agent on
if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
  ENABLE_MULTI_AGENT=1
fi

if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
  OUTPUT_DIR="${REPO_ROOT}/results/raw/pinchbench/multi_agent"
else
OUTPUT_DIR="${REPO_ROOT}/results/raw/pinchbench/ecoclaw"
fi
LOG_DIR="${REPO_ROOT}/log"
RUN_TAG="$(date +%Y%m%d_%H%M%S)"
RUN_LOG_PREFIX="${LOG_DIR}/pinchbench_ecoclaw_${RUN_TAG}"
RUN_LOG_FILE="${RUN_LOG_PREFIX}_generate.log"
EVAL_LOG_FILE="${RUN_LOG_PREFIX}_eval.log"
EVAL_JSONL_FILE="${RUN_LOG_PREFIX}_eval.jsonl"
RUN_START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"
export PINCHBENCH_EVAL_LOG_FILE="${EVAL_LOG_FILE}"
export PINCHBENCH_EVAL_JSONL_FILE="${EVAL_JSONL_FILE}"

PLUGIN_TRACE_FILE="${HOME}/.openclaw/ecoclaw-plugin-state/task-state/trace.jsonl"
GATEWAY_LOG_FILE="/tmp/openclaw_gateway.log"
TRACE_TAIL_PID=""
GATEWAY_TAIL_PID=""

cleanup_live_debug_tails() {
  if [[ -n "${TRACE_TAIL_PID}" ]]; then
    kill "${TRACE_TAIL_PID}" >/dev/null 2>&1 || true
    wait "${TRACE_TAIL_PID}" >/dev/null 2>&1 || true
    TRACE_TAIL_PID=""
  fi
  if [[ -n "${GATEWAY_TAIL_PID}" ]]; then
    kill "${GATEWAY_TAIL_PID}" >/dev/null 2>&1 || true
    wait "${GATEWAY_TAIL_PID}" >/dev/null 2>&1 || true
    GATEWAY_TAIL_PID=""
  fi
}

run_ecoclaw_exit_cleanup() {
  cleanup_live_debug_tails
  if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
    restore_openclaw_config || true
  fi
}

start_live_debug_tails() {
  mkdir -p "$(dirname "${PLUGIN_TRACE_FILE}")"
  : > "${PLUGIN_TRACE_FILE}"
  (
    stdbuf -oL tail -n 0 -F "${PLUGIN_TRACE_FILE}" 2>/dev/null \
      | python3 -u -c '
import json, sys
interesting = {
    "task_state_estimator_applied",
    "registry_driven_eviction_evaluated",
    "canonical_eviction_closure_checked",
    "canonical_eviction_applied",
    "canonical_state_sync",
    "canonical_state_rewrite",
}
for raw in sys.stdin:
    line = raw.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    if obj.get("stage") not in interesting:
        continue
    print("[plugin-trace] " + json.dumps(obj, ensure_ascii=False), flush=True)
' || true
  ) &
  TRACE_TAIL_PID=$!

  touch "${GATEWAY_LOG_FILE}"
  (
    stdbuf -oL tail -n 0 -F "${GATEWAY_LOG_FILE}" 2>/dev/null \
      | python3 -u -c '
import sys
for raw in sys.stdin:
    line = raw.rstrip("\n")
    if "ecoclaw" not in line.lower():
        continue
    print("[gateway-log] " + line, flush=True)
' || true
  ) &
  GATEWAY_TAIL_PID=$!
}

# Multi-agent config injection
if [[ "${ENABLE_MULTI_AGENT}" == "1" ]]; then
  backup_openclaw_config
  if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
    # Resolve skills dir: experiments/skills/ relative to the agent-config location
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
start_live_debug_tails
trap 'run_ecoclaw_exit_cleanup' EXIT
uv run scripts/benchmark.py "${BENCH_ARGS[@]}" \
  2>&1 | tee "${RUN_LOG_FILE}"
cleanup_live_debug_tails

echo "Run log saved to: ${RUN_LOG_FILE}"
if [[ -f "${EVAL_LOG_FILE}" ]]; then
  echo "Eval log saved to: ${EVAL_LOG_FILE}"
fi
if [[ -f "${EVAL_JSONL_FILE}" ]]; then
  echo "Eval jsonl saved to: ${EVAL_JSONL_FILE}"
fi

RESULT_JSON="$(latest_json_in_dir "${OUTPUT_DIR}" || true)"
if [[ -n "${RESULT_JSON}" ]]; then
  COST_REPORT_DIR="${REPO_ROOT}/results/reports"
  COST_REPORT_FILE="${COST_REPORT_DIR}/ecoclaw_${RUN_TAG}_cost.json"
  REDUCTION_TRACE_FILE="${HOME}/.openclaw/ecoclaw-plugin-state/ecoclaw/reduction-pass-trace.jsonl"
  REDUCTION_REPORT_FILE="${COST_REPORT_DIR}/ecoclaw_${RUN_TAG}_reduction_passes.json"
  mkdir -p "${COST_REPORT_DIR}"
  generate_cost_report_and_print_summary "${RESULT_JSON}" "${COST_REPORT_FILE}"
  generate_reduction_pass_report_and_print_summary "${REDUCTION_TRACE_FILE}" "${REDUCTION_REPORT_FILE}" "${RUN_START_ISO}"
else
  echo "Cost report skipped: no result JSON found in ${OUTPUT_DIR}" >&2
fi
