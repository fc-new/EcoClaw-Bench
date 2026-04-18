#!/usr/bin/env bash
set -euo pipefail

# ── AgentSwing Context Management Benchmark — Claw-Eval ──
# Runs Claw-Eval with AgentSwing context engine (Keep-Last-N or Summary).
# This is a SAS (Single Agent System) benchmark — no multi-agent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

MODEL=""
JUDGE=""
SUITE=""
RUNS=""
TIMEOUT_MULTIPLIER=""
PARALLEL=""
CONTEXT_MODE=""
TRIGGER_MODE=""
TRIGGER_RATIO=""
TRIGGER_TURN_COUNT=""
KEEP_LAST_N=""
CONTEXT_WINDOW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="${2:-}"; shift 2 ;;
    --judge) JUDGE="${2:-}"; shift 2 ;;
    --suite) SUITE="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --timeout-multiplier) TIMEOUT_MULTIPLIER="${2:-}"; shift 2 ;;
    --parallel) PARALLEL="${2:-}"; shift 2 ;;
    --context-mode) CONTEXT_MODE="${2:-}"; shift 2 ;;
    --trigger-mode) TRIGGER_MODE="${2:-}"; shift 2 ;;
    --trigger-ratio) TRIGGER_RATIO="${2:-}"; shift 2 ;;
    --trigger-turn-count) TRIGGER_TURN_COUNT="${2:-}"; shift 2 ;;
    --keep-last-n) KEEP_LAST_N="${2:-}"; shift 2 ;;
    --context-window) CONTEXT_WINDOW="${2:-}"; shift 2 ;;
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

if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/claw-eval-skill" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/claw-eval-skill"
fi
if [[ -z "${ECOCLAW_SKILL_DIR:-}" && -d "${REPO_ROOT}/experiments/dataset/claw_eval" ]]; then
  export ECOCLAW_SKILL_DIR="${REPO_ROOT}/experiments/dataset/claw_eval"
fi

# Resolve parameters
MODEL_LIKE="${MODEL:-${ECOCLAW_MODEL:-dmxapi/gpt-5-mini}}"
JUDGE_LIKE="${JUDGE:-${ECOCLAW_JUDGE:-dmxapi/gpt-5-mini}}"
RESOLVED_MODEL="$(resolve_model_alias "${MODEL_LIKE}")"
RESOLVED_JUDGE="$(resolve_model_alias "${JUDGE_LIKE}")"
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-all}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-1}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"
RESOLVED_PARALLEL="${PARALLEL:-${ECOCLAW_PARALLEL:-1}}"

# Context engine parameters
RESOLVED_CONTEXT_MODE="${CONTEXT_MODE:-${AGENTSWING_MODE:-keep-last-n}}"
RESOLVED_TRIGGER_MODE="${TRIGGER_MODE:-${AGENTSWING_TRIGGER_MODE:-token-ratio}}"
RESOLVED_TRIGGER_RATIO="${TRIGGER_RATIO:-${AGENTSWING_TRIGGER_RATIO:-0.4}}"
RESOLVED_TRIGGER_TURN_COUNT="${TRIGGER_TURN_COUNT:-${AGENTSWING_TRIGGER_TURN_COUNT:-10}}"
RESOLVED_KEEP_LAST_N="${KEEP_LAST_N:-${AGENTSWING_KEEP_LAST_N:-5}}"
RESOLVED_CONTEXT_WINDOW="${CONTEXT_WINDOW:-${AGENTSWING_CONTEXT_WINDOW:-}}"

# Validate context mode
if [[ "${RESOLVED_CONTEXT_MODE}" != "keep-last-n" ]] && [[ "${RESOLVED_CONTEXT_MODE}" != "summary" ]]; then
  echo "ERROR: --context-mode must be 'keep-last-n' or 'summary', got: ${RESOLVED_CONTEXT_MODE}" >&2
  exit 1
fi

# Validate trigger mode
if [[ "${RESOLVED_TRIGGER_MODE}" != "token-ratio" ]] && [[ "${RESOLVED_TRIGGER_MODE}" != "turn-count" ]]; then
  echo "ERROR: --trigger-mode must be 'token-ratio' or 'turn-count', got: ${RESOLVED_TRIGGER_MODE}" >&2
  exit 1
fi

# Sanitize mode for directory names (keep-last-n → keep_last_n)
MODE_SLUG="${RESOLVED_CONTEXT_MODE//-/_}"
OUTPUT_DIR="${REPO_ROOT}/results/raw/claw_eval/agentswing_${MODE_SLUG}"
LOG_DIR="${REPO_ROOT}/log"
RUN_TAG="$(date +%Y%m%d_%H%M%S)"
RUN_LOG_FILE="${LOG_DIR}/claw_eval_agentswing_${MODE_SLUG}_${RUN_TAG}.log"
BENCHMARK_LOG_FILE="${LOG_DIR}/claw_eval_agentswing_${MODE_SLUG}_${RUN_TAG}_benchmark.log"
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

# Disable EcoClaw plugin (baseline behavior) + remember state for restore
ECOCLAW_WAS_ENABLED=0
if openclaw plugins list 2>/dev/null | grep -qE '│ EcoClaw[[:space:]]+│ ecoclaw[[:space:]]+│ loaded[[:space:]]+│'; then
  ECOCLAW_WAS_ENABLED=1
fi
openclaw plugins disable ecoclaw >/dev/null 2>&1 || true

# Backup config and inject context engine
backup_openclaw_config

# Export env vars for the plugin (read by index.ts at runtime)
export AGENTSWING_MODE="${RESOLVED_CONTEXT_MODE}"
export AGENTSWING_TRIGGER_MODE="${RESOLVED_TRIGGER_MODE}"
export AGENTSWING_TRIGGER_RATIO="${RESOLVED_TRIGGER_RATIO}"
export AGENTSWING_TRIGGER_TURN_COUNT="${RESOLVED_TRIGGER_TURN_COUNT}"
export AGENTSWING_KEEP_LAST_N="${RESOLVED_KEEP_LAST_N}"
if [[ -n "${RESOLVED_CONTEXT_WINDOW}" ]]; then
  export AGENTSWING_CONTEXT_WINDOW="${RESOLVED_CONTEXT_WINDOW}"
fi

# For summary mode: pass API credentials for LLM summarization calls
if [[ "${RESOLVED_CONTEXT_MODE}" == "summary" ]]; then
  export AGENTSWING_SUMMARY_API_BASE="${AGENTSWING_SUMMARY_API_BASE:-${ECOCLAW_API_BASE:-}}"
  export AGENTSWING_SUMMARY_API_KEY="${AGENTSWING_SUMMARY_API_KEY:-${ECOCLAW_API_KEY:-}}"
  export AGENTSWING_SUMMARY_MODEL="${AGENTSWING_SUMMARY_MODEL:-${RESOLVED_MODEL#*/}}"
fi

inject_context_engine_config \
  "${RESOLVED_CONTEXT_MODE}" \
  "${RESOLVED_TRIGGER_MODE}" \
  "${RESOLVED_TRIGGER_RATIO}" \
  "${RESOLVED_TRIGGER_TURN_COUNT}" \
  "${RESOLVED_KEEP_LAST_N}" \
  "${RESOLVED_CONTEXT_WINDOW}"

# Restart gateway to pick up plugin config
pkill -f 'openclaw-gateway' 2>/dev/null || true
sleep 1
ensure_openclaw_gateway_running

# Restore on exit
cleanup_agentswing() {
  restore_openclaw_config || true
  if [[ "${ECOCLAW_WAS_ENABLED}" == "1" ]]; then
    openclaw plugins enable ecoclaw >/dev/null 2>&1 || true
  fi
  pkill -f 'openclaw-gateway' 2>/dev/null || true
  sleep 1
  ensure_openclaw_gateway_running 2>/dev/null || true
}
trap cleanup_agentswing EXIT

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AgentSwing Claw-Eval Run"
echo "  Mode:          ${RESOLVED_CONTEXT_MODE}"
echo "  Trigger Mode:  ${RESOLVED_TRIGGER_MODE}"
echo "  Trigger Ratio: ${RESOLVED_TRIGGER_RATIO}"
echo "  Trigger Turns: ${RESOLVED_TRIGGER_TURN_COUNT}"
echo "  Keep Last N:   ${RESOLVED_KEEP_LAST_N}"
echo "  Model:         ${RESOLVED_MODEL}"
echo "  Judge:         ${RESOLVED_JUDGE}"
echo "  Suite:         ${RESOLVED_SUITE}"
echo "  Output:        ${OUTPUT_DIR}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Build benchmark.py arguments (SAS mode — no multi-agent flags)
BENCH_ARGS=(
  --model "${RESOLVED_MODEL}"
  --judge "${RESOLVED_JUDGE}"
  --suite "${RESOLVED_SUITE}"
  --runs "${RESOLVED_RUNS}"
  --parallel "${RESOLVED_PARALLEL}"
  --timeout-multiplier "${RESOLVED_TIMEOUT}"
  --output-dir "${OUTPUT_DIR}"
  --no-upload
  --context-mode "${RESOLVED_CONTEXT_MODE}"
)

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
  COST_REPORT_FILE="${COST_REPORT_DIR}/agentswing_claw_eval_${MODE_SLUG}_${RUN_TAG}_cost.json"
  mkdir -p "${COST_REPORT_DIR}"
  generate_cost_report_and_print_summary "${RESULT_JSON}" "${COST_REPORT_FILE}"
else
  echo "Cost report skipped: no result JSON found in ${OUTPUT_DIR}" >&2
fi
