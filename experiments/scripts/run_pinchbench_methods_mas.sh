#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# EcoClaw Methods × Multi-Agent System (MAS) Runner
#
# Runs PinchBench with each token-saving method enabled under multi-agent mode
# (coordinator → worker architecture via sessions_spawn).
#
# This script combines:
#   - run_pinchbench_methods.sh   (per-method ablation toggling)
#   - run_pinchbench_ecoclaw.sh   (MAS config injection & agent topology)
#
# Results go to results/raw/pinchbench/mas-<label>/ for comparison with
# single-agent results in results/raw/pinchbench/<label>/.
#
# Usage:
#   # Run a single method in MAS mode (轻量模式 — all agents use same model):
#   ./experiments/scripts/run_pinchbench_methods_mas.sh --label ccr-only
#
#   # Run a single method with full agent-config (推荐 — per-agent model/skills):
#   ./experiments/scripts/run_pinchbench_methods_mas.sh --label ccr-only \
#       --agent-config experiments/agent-config/pinchbench_agents.json
#
#   # Run ALL methods in MAS mode:
#   ./experiments/scripts/run_pinchbench_methods_mas.sh --all
#
#   # Run ALL methods with agent-config:
#   ./experiments/scripts/run_pinchbench_methods_mas.sh --all \
#       --agent-config experiments/agent-config/pinchbench_agents.json
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
AGENT_CONFIG=""
MULTI_AGENT_ROLES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) LABEL="${2:-}"; shift 2 ;;
    --all) RUN_ALL=true; shift ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --judge) JUDGE="${2:-}"; shift 2 ;;
    --suite) SUITE="${2:-}"; shift 2 ;;
    --runs) RUNS="${2:-}"; shift 2 ;;
    --timeout-multiplier) TIMEOUT_MULTIPLIER="${2:-}"; shift 2 ;;
    --agent-config) AGENT_CONFIG="${2:-}"; shift 2 ;;
    --multi-agent-roles) MULTI_AGENT_ROLES="${2:-}"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --label <method-label> [--agent-config <path>]" >&2
      echo "       $0 --all [--agent-config <path>]" >&2
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
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-automated-only}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-1}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"
RESOLVED_MULTI_AGENT_ROLES="${MULTI_AGENT_ROLES:-${ECOCLAW_MULTI_AGENT_ROLES:-researcher,coder}}"

# Resolve agent-config to absolute path early (before any cd)
RESOLVED_AGENT_CONFIG="${AGENT_CONFIG:-${ECOCLAW_AGENT_CONFIG:-}}"
if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
  RESOLVED_AGENT_CONFIG="$(cd "$(dirname "${RESOLVED_AGENT_CONFIG}")" && pwd)/$(basename "${RESOLVED_AGENT_CONFIG}")"
fi

SKILL_DIR="$(resolve_skill_dir)"

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

# ── MAS config injection helper ───────────────────────────────────────────────
# Injects MAS topology into openclaw.json, returns 0.
# Must be called AFTER ensure_openclaw_gateway_running.

inject_mas_config() {
  backup_openclaw_config

  if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
    # Full mode: per-agent model/skills from config file
    local agent_config_dir
    agent_config_dir="$(cd "$(dirname "${RESOLVED_AGENT_CONFIG}")" && pwd)"
    local skills_dir="${agent_config_dir}/../skills"
    if [[ -d "${skills_dir}" ]]; then
      skills_dir="$(cd "${skills_dir}" && pwd)"
    else
      skills_dir=""
    fi
    inject_agent_config_from_file "${RESOLVED_AGENT_CONFIG}" "${skills_dir}"
  else
    # Lightweight mode: all agents share the same model
    local subagent_thinking="${ECOCLAW_SUBAGENT_THINKING:-medium}"
    local subagent_max_concurrent="${ECOCLAW_SUBAGENT_MAX_CONCURRENT:-4}"
    inject_multi_agent_config "${RESOLVED_MODEL}" "${subagent_thinking}" "${subagent_max_concurrent}"
  fi
}

# ── Single-label run function ─────────────────────────────────────────────────

run_single() {
  local label="$1"

  # Start with all EcoClaw method modules disabled
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
    baseline)           ;; # all methods off, MAS only
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
      # Enable LycheeMem plugin, disable other memory/compaction methods
      openclaw config set plugins.entries.lycheemem-tools.enabled true 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
      openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    compaction)
      # Enable safeguard compaction, disable lossless-claw
      openclaw config set agents.defaults.compaction.mode safeguard 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    compaction-lcm)
      # Enable safeguard compaction + lossless-claw
      openclaw config set agents.defaults.compaction.mode safeguard 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled true 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    openspace|openspace-cold)
      # OpenSpace Phase 1 — cold start: agent delegates ALL tasks via execute_task
      start_openspace_server cold
      register_openspace_plugin
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    openspace-hot)
      # OpenSpace Phase 2 — hot rerun: uses skill library built by openspace-cold
      start_openspace_server hot
      register_openspace_plugin
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    openspace-compaction)
      # OpenSpace + safeguard compaction
      start_openspace_server
      register_openspace_plugin
      openclaw config set agents.defaults.compaction.mode safeguard 2>/dev/null || true
      openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      ;;
    *)
      echo "Unknown label: ${label}" >&2
      echo "Valid labels: baseline, prefix-cache, qmd-only, qmd-vsearch, qmd-query, ccr-only," >&2
      echo "  llmlingua-only, selctx-only, tokenqrusher-only, concise-only, slim-prompt, concise-slim," >&2
      echo "  lycheemem, compaction, compaction-lcm, openspace-cold, openspace-hot, openspace-compaction" >&2
      return 1
      ;;
  esac

  # For baseline / tokenqrusher: ensure compaction is in default mode and all extra plugins disabled
  if [[ "${label}" == "baseline" || "${label}" == "tokenqrusher-only" ]]; then
    openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
    openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
    openclaw config set plugins.entries.lycheemem-tools.enabled false 2>/dev/null || true
    openclaw gateway restart 2>/dev/null || true
    sleep 3
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 Method + MAS: ${label}"
  echo "  Model: ${RESOLVED_MODEL}"
  echo "  Agent Config: ${RESOLVED_AGENT_CONFIG:-<lightweight mode>}"
  echo "  PREFIX_CACHE=${ECOCLAW_ENABLE_PREFIX_CACHE}  CACHE=${ECOCLAW_ENABLE_CACHE}  SUMMARY=${ECOCLAW_ENABLE_SUMMARY}"
  echo "  COMPRESSION=${ECOCLAW_ENABLE_COMPRESSION}  RETRIEVAL=${ECOCLAW_ENABLE_RETRIEVAL}  ROUTER=${ECOCLAW_ENABLE_ROUTER}"
  echo "  QMD=${ECOCLAW_ENABLE_QMD}  CCR=${ECOCLAW_ENABLE_CCR}  LLMLINGUA=${ECOCLAW_ENABLE_LLMLINGUA}  SELCTX=${ECOCLAW_ENABLE_SELCTX}"
  echo "  CONCISE=${ECOCLAW_ENABLE_CONCISE}  SLIM_PROMPT=${ECOCLAW_ENABLE_SLIM_PROMPT}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local output_dir="${REPO_ROOT}/results/raw/pinchbench/mas-${label}"
  mkdir -p "${output_dir}"

  # ── Inject MAS topology ─────────────────────────────────────────────────
  ensure_openclaw_gateway_running
  recover_stale_openclaw_config_backup
  inject_mas_config
  _mas_bench_exit_cleanup() {
    if [[ "${label}" == "tokenqrusher-only" ]]; then
      "${SCRIPT_DIR}/disable_tokenqrusher_hooks.sh" || true
    fi
    restore_openclaw_config || true
  }
  trap _mas_bench_exit_cleanup EXIT

  # ── Build benchmark.py arguments ────────────────────────────────────────
  local bench_args=(
    --model "${RESOLVED_MODEL}"
    --judge "${RESOLVED_JUDGE}"
    --suite "${RESOLVED_SUITE}"
    --runs "${RESOLVED_RUNS}"
    --timeout-multiplier "${RESOLVED_TIMEOUT}"
    --output-dir "${output_dir}"
    --no-upload
    --enable-multi-agent
  )

  if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
    bench_args+=(--agent-config "${RESOLVED_AGENT_CONFIG}")
  else
    bench_args+=(--multi-agent-roles "${RESOLVED_MULTI_AGENT_ROLES}")
  fi

  # MAS 逻辑在当前仓库的 experiments/dataset/pinchbench 下实现
  # 因此我们需要用本仓库的 benchmark.py，而不是 SKILL_DIR 中的原始版本
  local bench_dir="${REPO_ROOT}/experiments/dataset/pinchbench"
  cd "${bench_dir}"
  uv run scripts/benchmark.py "${bench_args[@]}"

  echo ""
  echo "  ✅ mas-${label} complete → ${output_dir}"
  echo ""

  # ── Restore openclaw config & cleanup gateway-level plugins ─────────────
  if [[ "${label}" == "tokenqrusher-only" ]]; then
    "${SCRIPT_DIR}/disable_tokenqrusher_hooks.sh" || true
  fi
  restore_openclaw_config || true
  # Reset the EXIT trap since we've already restored
  trap - EXIT

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

ALL_LABELS=(
  baseline
  prefix-cache
  qmd-only
  qmd-vsearch
  qmd-query
  ccr-only
  llmlingua-only
  selctx-only
  tokenqrusher-only
  concise-only
  slim-prompt
  concise-slim
  lycheemem
  compaction
  compaction-lcm
  openspace-cold
  openspace-hot
  openspace-compaction
)

if [[ "${RUN_ALL}" == "true" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🤖 Running all ${#ALL_LABELS[@]} methods in MULTI-AGENT mode"
  if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
    echo "  Agent Config: ${RESOLVED_AGENT_CONFIG}"
  else
    echo "  Mode: lightweight (all agents share model ${RESOLVED_MODEL})"
    echo "  Roles: ${RESOLVED_MULTI_AGENT_ROLES}"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  for lbl in "${ALL_LABELS[@]}"; do
    run_single "${lbl}"
  done
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🎉 All ${#ALL_LABELS[@]} MAS method runs complete!"
  echo "  Results in: results/raw/pinchbench/mas-*/"
  echo "  Compare with single-agent results in: results/raw/pinchbench/<label>/"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
elif [[ -n "${LABEL}" ]]; then
  run_single "${LABEL}"
else
  echo "Usage: $0 --label <method-label> [--agent-config <path>]" >&2
  echo "       $0 --all [--agent-config <path>]" >&2
  echo "" >&2
  echo "Available labels:" >&2
  echo "  baseline, prefix-cache, qmd-only, qmd-vsearch, qmd-query, ccr-only," >&2
  echo "  llmlingua-only, selctx-only, tokenqrusher-only, concise-only, slim-prompt, concise-slim," >&2
  echo "  lycheemem, compaction, compaction-lcm, openspace-cold, openspace-hot, openspace-compaction" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --agent-config <path>  Use full agent topology (recommended)" >&2
  echo "  --multi-agent-roles    Worker roles for lightweight mode (default: researcher,coder)" >&2
  echo "  --model                Model identifier" >&2
  echo "  --judge                Judge model identifier" >&2
  echo "  --suite                Task suite (default: automated-only)" >&2
  echo "  --runs                 Runs per task (default: 1)" >&2
  echo "  --timeout-multiplier   Timeout multiplier (default: 1.0)" >&2
  exit 1
fi