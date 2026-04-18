#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# EcoClaw Ablation Runner — Claw-Eval
#
# Runs Claw-Eval with exactly ONE EcoClaw module enabled (or none for baseline).
# Results go to results/raw/claw_eval/<label>/ for later comparison.
#
# Usage:
#   ./experiments/scripts/run_claw_eval_methods.sh --label baseline
#   ./experiments/scripts/run_claw_eval_methods.sh --label baseline --execution-mode serial
#   ./experiments/scripts/run_claw_eval_methods.sh --label qmd-only
#   ./experiments/scripts/run_claw_eval_methods.sh --label ccr-only
#   ./experiments/scripts/run_claw_eval_methods.sh --label llmlingua-only
#   ./experiments/scripts/run_claw_eval_methods.sh --label selctx-only
#   ./experiments/scripts/run_claw_eval_methods.sh --label tokenqrusher-only
#   ./experiments/scripts/run_claw_eval_methods.sh --label concise-only
#
# Or run all in sequence:
#   ./experiments/scripts/run_claw_eval_methods.sh --all
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# Ensure nvm is loaded for openclaw CLI
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 22 >/dev/null 2>&1 || true


LABEL=""
RUN_ALL=false
MODEL=""
JUDGE=""
SUITE=""
RUNS=""
TIMEOUT_MULTIPLIER=""
PARALLEL=""
EXECUTION_MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) LABEL="${2:-}"; shift 2 ;;
    --all) RUN_ALL=true; shift ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --judge) JUDGE="${2:-}"; shift 2 ;;
    --suite) SUITE="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --timeout-multiplier) TIMEOUT_MULTIPLIER="${2:-}"; shift 2 ;;
    --parallel) PARALLEL="${2:-}"; shift 2 ;;
    --execution-mode) EXECUTION_MODE="${2:-}"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --label <baseline|prefix-cache|qmd-only|...>" >&2
      echo "       $0 --all [--execution-mode parallel|serial] [--parallel N]" >&2
      exit 1
      ;;
  esac
done

import_dotenv
apply_ecoclaw_env

# ── Resolve common parameters ────────────────────────────────────────────────

MODEL_LIKE="${MODEL:-${ECOCLAW_MODEL:-dmx/gpt-5.4-mini}}"
JUDGE_LIKE="${JUDGE:-${ECOCLAW_JUDGE:-dmx/gpt-5.4-mini}}"
RESOLVED_MODEL="$(resolve_model_alias "${MODEL_LIKE}")"
RESOLVED_JUDGE="$(resolve_model_alias "${JUDGE_LIKE}")"
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-all}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-1}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"
RESOLVED_PARALLEL="${PARALLEL:-${ECOCLAW_PARALLEL:-1}}"
RESOLVED_EXECUTION_MODE="${EXECUTION_MODE:-${ECOCLAW_EXECUTION_MODE:-parallel}}"
case "${RESOLVED_EXECUTION_MODE}" in
  parallel)
    RESOLVED_SESSION_MODE="isolated"
    ;;
  serial)
    RESOLVED_PARALLEL=1
    RESOLVED_SESSION_MODE="continuous"
    ;;
  *)
    echo "Unknown execution mode: ${RESOLVED_EXECUTION_MODE}" >&2
    echo "Valid values: parallel, serial" >&2
    exit 1
    ;;
esac

# Claw-Eval code + tasks + assets
CLAW_EVAL_ROOT="${REPO_ROOT}/experiments/dataset/claw_eval"
CLAW_EVAL_BENCHMARK_PY="${CLAW_EVAL_ROOT}/scripts/benchmark.py"
if [[ ! -f "${CLAW_EVAL_BENCHMARK_PY}" ]]; then
  printf 'Claw-Eval benchmark not found: %s\n' "${CLAW_EVAL_BENCHMARK_PY}" >&2
  exit 1
fi

# ── Cleanup: reset all gateway-level plugins to safe defaults ─────────────────

reset_gateway_plugins() {
  echo "  🔄 Resetting gateway plugins to defaults..."
  openclaw config set plugins.entries.lycheemem-tools.enabled false 2>/dev/null || true
  openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
  openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
  openclaw gateway restart 2>/dev/null || true
  sleep 3
  echo "  ✅ Gateway plugins reset"
}

reset_openspace() {
  stop_openspace_server
  unregister_openspace_plugin
  reset_gateway_plugins
}

# ── Single-label run function ─────────────────────────────────────────────────

run_single() {
  local label="$1"

  # Start with all modules disabled
  export ECOCLAW_ENABLE_PREFIX_CACHE=0
  export ECOCLAW_ENABLE_CACHE=0
  export ECOCLAW_ENABLE_SUMMARY=0
  export ECOCLAW_ENABLE_COMPRESSION=0
  export ECOCLAW_ENABLE_RETRIEVAL=0
  export ECOCLAW_ENABLE_ROUTER=0
  export ECOCLAW_ENABLE_QMD=0
  export ECOCLAW_ENABLE_CCR=0
  export ECOCLAW_ENABLE_LLMLINGUA=0
  export ECOCLAW_ENABLE_SELCTX=0
  export ECOCLAW_ENABLE_CONCISE=0
  export ECOCLAW_ENABLE_SLIM_PROMPT=0
  export ECOCLAW_COMPACTION_MODE=""

  # Enable the one module matching the label
  case "${label}" in
    baseline)           ;; # all off
    prefix-cache)       export ECOCLAW_ENABLE_PREFIX_CACHE=1 ;;
    qmd-only)           export ECOCLAW_ENABLE_QMD=1; export ECOCLAW_QMD_MODE=search ;;
    qmd-vsearch)        export ECOCLAW_ENABLE_QMD=1; export ECOCLAW_QMD_MODE=vsearch ;;
    qmd-query)          export ECOCLAW_ENABLE_QMD=1; export ECOCLAW_QMD_MODE=query ;;
    ccr-only)           export ECOCLAW_ENABLE_CCR=1 ;;
    llmlingua-only)     export ECOCLAW_ENABLE_LLMLINGUA=1 ;;
    selctx-only)        export ECOCLAW_ENABLE_SELCTX=1 ;;
    tokenqrusher-only)
      "${SCRIPT_DIR}/enable_tokenqrusher_hooks.sh"
      ;;
    concise-only)       export ECOCLAW_ENABLE_CONCISE=1 ;;
    slim-prompt)        export ECOCLAW_ENABLE_SLIM_PROMPT=1 ;;
    concise-slim)       export ECOCLAW_ENABLE_CONCISE=1; export ECOCLAW_ENABLE_SLIM_PROMPT=1 ;;
    lycheemem)
      openclaw config set plugins.entries.lycheemem-tools.enabled true 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
      openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    compaction)
      openclaw config set agents.defaults.compaction.mode safeguard 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    compaction-lcm)
      openclaw config set agents.defaults.compaction.mode safeguard 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled true 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    openspace|openspace-cold)
      start_openspace_server cold
      register_openspace_plugin
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    openspace-hot)
      start_openspace_server hot
      register_openspace_plugin
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    openspace-compaction)
      start_openspace_server
      register_openspace_plugin
      openclaw config set agents.defaults.compaction.mode safeguard 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    *)
      echo "Unknown label: ${label}" >&2
      return 1
      ;;
  esac

  if [[ "${label}" == "baseline" || "${label}" == "tokenqrusher-only" ]]; then
    openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
    openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
    openclaw config set plugins.entries.lycheemem-tools.enabled false 2>/dev/null || true
    openclaw gateway restart 2>/dev/null || true
    sleep 3
  fi

  if [[ "${label}" == "tokenqrusher-only" ]]; then
    _tokenqrusher_claw_eval_cleanup() {
      "${SCRIPT_DIR}/disable_tokenqrusher_hooks.sh" || true
    }
    trap _tokenqrusher_claw_eval_cleanup EXIT INT TERM
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 Ablation [claw_eval]: ${label}"
  echo "  Model: ${RESOLVED_MODEL}"
  echo "  PREFIX_CACHE=${ECOCLAW_ENABLE_PREFIX_CACHE}  QMD=${ECOCLAW_ENABLE_QMD}  CCR=${ECOCLAW_ENABLE_CCR}"
  echo "  LLMLINGUA=${ECOCLAW_ENABLE_LLMLINGUA}  SELCTX=${ECOCLAW_ENABLE_SELCTX}"
  echo "  CONCISE=${ECOCLAW_ENABLE_CONCISE}  SLIM_PROMPT=${ECOCLAW_ENABLE_SLIM_PROMPT}"
  echo "  Execution Mode=${RESOLVED_EXECUTION_MODE}  Parallel=${RESOLVED_PARALLEL}  SessionMode=${RESOLVED_SESSION_MODE}"
  echo "  Claw-Eval: ${CLAW_EVAL_ROOT}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local output_dir="${REPO_ROOT}/results/raw/claw_eval/${label}"
  mkdir -p "${output_dir}"

  cd "${CLAW_EVAL_ROOT}"
  uv run "${CLAW_EVAL_BENCHMARK_PY}" \
    --model "${RESOLVED_MODEL}" \
    --judge "${RESOLVED_JUDGE}" \
    --suite "${RESOLVED_SUITE}" \
    --runs "${RESOLVED_RUNS}" \
    --parallel "${RESOLVED_PARALLEL}" \
    --session-mode "${RESOLVED_SESSION_MODE}" \
    --timeout-multiplier "${RESOLVED_TIMEOUT}" \
    --output-dir "${output_dir}" \
    --no-upload

  echo ""
  echo "  ✅ ${label} complete → ${output_dir}"
  echo ""

  if [[ "${label}" == "tokenqrusher-only" ]]; then
    trap - EXIT INT TERM
    "${SCRIPT_DIR}/disable_tokenqrusher_hooks.sh" || true
  fi

  case "${label}" in
    lycheemem|compaction|compaction-lcm|baseline)
      reset_gateway_plugins
      ;;
    openspace|openspace-cold|openspace-hot|openspace-compaction)
      reset_openspace
      ;;
  esac
}

# ── Main ──────────────────────────────────────────────────────────────────────

ALL_LABELS=(baseline prefix-cache qmd-only qmd-vsearch qmd-query ccr-only llmlingua-only selctx-only tokenqrusher-only concise-only slim-prompt concise-slim lycheemem compaction compaction-lcm openspace-cold openspace-hot openspace-compaction)

if [[ "${RUN_ALL}" == "true" ]]; then
  echo "Running all ${#ALL_LABELS[@]} ablation experiments on claw_eval..."
  for lbl in "${ALL_LABELS[@]}"; do
    run_single "${lbl}"
  done
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🎉 All ${#ALL_LABELS[@]} ablation runs complete (claw_eval)!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
elif [[ -n "${LABEL}" ]]; then
  run_single "${LABEL}"
else
  echo "Usage: $0 --label <baseline|prefix-cache|qmd-only|...>" >&2
  echo "       $0 --all [--execution-mode parallel|serial] [--parallel N]" >&2
  exit 1
fi
