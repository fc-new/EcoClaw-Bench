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
#   ./experiments/scripts/run_pinchbench_methods_mas.sh --label evermemos
#   ./experiments/scripts/run_pinchbench_methods_mas.sh --label token-opt
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

# Resolve agent-config to absolute path early (before any cd).
# MAS runner only uses explicit --agent-config to avoid accidental overrides
# from .env (e.g., stale ECOCLAW_AGENT_CONFIG with incompatible models).
RESOLVED_AGENT_CONFIG="${AGENT_CONFIG:-}"
if [[ -z "${AGENT_CONFIG:-}" && -n "${ECOCLAW_AGENT_CONFIG:-}" ]]; then
  echo "Ignoring ECOCLAW_AGENT_CONFIG from .env for MAS runner. Pass --agent-config explicitly if needed."
fi
if [[ -n "${RESOLVED_AGENT_CONFIG}" ]]; then
  if [[ "${RESOLVED_AGENT_CONFIG}" != /* ]]; then
    RESOLVED_AGENT_CONFIG="${REPO_ROOT}/${RESOLVED_AGENT_CONFIG}"
  fi
  RESOLVED_AGENT_CONFIG="$(cd "$(dirname "${RESOLVED_AGENT_CONFIG}")" && pwd)/$(basename "${RESOLVED_AGENT_CONFIG}")"
  export ECOCLAW_AGENT_CONFIG="${RESOLVED_AGENT_CONFIG}"
else
  unset ECOCLAW_AGENT_CONFIG || true
fi

# ── Cleanup: reset all gateway-level plugins to safe defaults ─────────────────

reset_gateway_plugins() {
  echo "  🔄 Resetting gateway plugins to defaults..."
  openclaw config set plugins.entries.lycheemem-tools.enabled false 2>/dev/null || true
  openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
  openclaw config set plugins.entries.evermemos-openclaw-plugin.enabled false 2>/dev/null || true
  openclaw config set plugins.slots.memory memory-core 2>/dev/null || true
  openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
  openclaw gateway restart 2>/dev/null || true
  sleep 3
  echo "  ✅ Gateway plugins reset"
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
  local token_opt_enabled=0
  local evermemos_enabled=0
  local config_patched=0
  local token_opt_script="${REPO_ROOT}/experiments/methods/static_tuning/openclaw-token-optimization-main/apply-preset.js"
  local evermemos_plugin_name="${ECOCLAW_EVERMEMOS_PLUGIN_NAME:-evermemos-openclaw-plugin}"
  local evermemos_plugin_dir="${ECOCLAW_EVERMEMOS_PLUGIN_DIR:-${REPO_ROOT}/experiments/methods/retrieval/EverMemOS-agent_memory/evermemos-openclaw-plugin}"
  local evermemos_base_url="${ECOCLAW_EVERMEMOS_BASE_URL:-http://localhost:1995}"
  local evermemos_user_id="${ECOCLAW_EVERMEMOS_USER_ID:-evermemos-user}"
  local evermemos_group_id="${ECOCLAW_EVERMEMOS_GROUP_ID:-evermemos-group}"
  local evermemos_top_k="${ECOCLAW_EVERMEMOS_TOP_K:-5}"
  local evermemos_retrieve_method="${ECOCLAW_EVERMEMOS_RETRIEVE_METHOD:-hybrid}"
  local evermemos_memory_types="${ECOCLAW_EVERMEMOS_MEMORY_TYPES:-episodic_memory,profile,agent_skill,agent_case}"

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
  export ECOCLAW_ENABLE_CONTEXT_SAVER=0
  export ECOCLAW_ENABLE_TOKEN_SAVER=0
  export ECOCLAW_ENABLE_ILANG=0
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
    evermemos)
      if [[ ! -d "${evermemos_plugin_dir}" ]]; then
        echo "EverMemOS plugin dir not found: ${evermemos_plugin_dir}" >&2
        return 1
      fi
      if [[ ! -f "${evermemos_plugin_dir}/openclaw.plugin.json" ]]; then
        echo "EverMemOS openclaw.plugin.json not found: ${evermemos_plugin_dir}/openclaw.plugin.json" >&2
        return 1
      fi
      if [[ ! -f "${OPENCLAW_CONFIG_PATH}" ]]; then
        echo "OpenClaw config not found: ${OPENCLAW_CONFIG_PATH}" >&2
        return 1
      fi
      if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 is required to apply EverMemOS plugin config" >&2
        return 1
      fi
      evermemos_enabled=1
      config_patched=1
      ;;
    context-saver-only) export ECOCLAW_ENABLE_CONTEXT_SAVER=1 ;;
    token-saver-only)   export ECOCLAW_ENABLE_TOKEN_SAVER=1 ;;
    ilang-only)         export ECOCLAW_ENABLE_ILANG=1 ;;
    concise-only)       export ECOCLAW_ENABLE_CONCISE=1 ;;
    slim-prompt)        export ECOCLAW_ENABLE_SLIM_PROMPT=1 ;;
    concise-slim)       export ECOCLAW_ENABLE_CONCISE=1; export ECOCLAW_ENABLE_SLIM_PROMPT=1 ;;
    token-opt)
      if [[ ! -f "${token_opt_script}" ]]; then
        echo "Token optimization preset script not found: ${token_opt_script}" >&2
        return 1
      fi
      token_opt_enabled=1
      config_patched=1
      ;;
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
    *)
      echo "Unknown label: ${label}" >&2
      echo "Valid labels: baseline, prefix-cache, qmd-only, qmd-vsearch, qmd-query, ccr-only, llmlingua-only, selctx-only, evermemos, context-saver-only, token-saver-only, ilang-only, concise-only, slim-prompt, concise-slim, token-opt, lycheemem, compaction, compaction-lcm" >&2
      return 1
      ;;
  esac

  # For baseline: ensure compaction is in default mode and all extra plugins disabled
  if [[ "${label}" == "baseline" ]]; then
    openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
    openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
    openclaw config set plugins.entries.lycheemem-tools.enabled false 2>/dev/null || true
    openclaw config set plugins.entries.evermemos-openclaw-plugin.enabled false 2>/dev/null || true
    openclaw config set plugins.slots.memory memory-core 2>/dev/null || true
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
  echo "  QMD=${ECOCLAW_ENABLE_QMD}  CCR=${ECOCLAW_ENABLE_CCR}  LLMLINGUA=${ECOCLAW_ENABLE_LLMLINGUA}  SELCTX=${ECOCLAW_ENABLE_SELCTX}  EVERMEMOS=${evermemos_enabled}  CONTEXT_SAVER=${ECOCLAW_ENABLE_CONTEXT_SAVER}  TOKEN_SAVER=${ECOCLAW_ENABLE_TOKEN_SAVER}  ILANG=${ECOCLAW_ENABLE_ILANG}"
  echo "  CONCISE=${ECOCLAW_ENABLE_CONCISE}  SLIM_PROMPT=${ECOCLAW_ENABLE_SLIM_PROMPT}"
  echo "  TOKEN_OPT=${token_opt_enabled}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local output_dir="${REPO_ROOT}/results/raw/pinchbench/mas-${label}"
  mkdir -p "${output_dir}"

  # ── Inject MAS topology ─────────────────────────────────────────────────
  ensure_openclaw_gateway_running
  recover_stale_openclaw_config_backup
  inject_mas_config
  trap 'restore_openclaw_config || true' EXIT

  if [[ "${evermemos_enabled}" == "1" ]]; then
    python3 - <<'PY' "${OPENCLAW_CONFIG_PATH}" "${evermemos_plugin_dir}" "${evermemos_plugin_name}" "${evermemos_base_url}" "${evermemos_user_id}" "${evermemos_group_id}" "${evermemos_top_k}" "${evermemos_retrieve_method}" "${evermemos_memory_types}"
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
plugin_dir = sys.argv[2]
plugin_name = sys.argv[3]
base_url = sys.argv[4]
user_id = sys.argv[5]
group_id = sys.argv[6]
top_k = int(sys.argv[7])
retrieve_method = sys.argv[8]
memory_types = [x.strip() for x in sys.argv[9].split(",") if x.strip()]

data = json.loads(config_path.read_text(encoding="utf-8"))
plugins = data.setdefault("plugins", {})
slots = plugins.setdefault("slots", {})
slots["memory"] = plugin_name
load = plugins.setdefault("load", {})
paths = load.setdefault("paths", [])
if plugin_dir not in paths:
    paths.append(plugin_dir)
entries = plugins.setdefault("entries", {})
entry = entries.setdefault(plugin_name, {})
entry["enabled"] = True
entry_cfg = entry.setdefault("config", {})
entry_cfg["baseUrl"] = base_url
entry_cfg["userId"] = user_id
entry_cfg["groupId"] = group_id
entry_cfg["topK"] = top_k
entry_cfg["memoryTypes"] = memory_types
entry_cfg["retrieveMethod"] = retrieve_method

config_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(config_path)
PY
    openclaw gateway restart 2>/dev/null || true
    sleep 3
  fi

  if [[ "${token_opt_enabled}" == "1" ]]; then
    node "${token_opt_script}"
    openclaw gateway restart 2>/dev/null || true
    sleep 3
  fi

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
  restore_openclaw_config || true
  # Reset the EXIT trap since we've already restored
  trap - EXIT
  if [[ "${config_patched}" == "1" ]]; then
    openclaw gateway restart 2>/dev/null || true
    sleep 3
  fi

  case "${label}" in
    lycheemem|compaction|compaction-lcm|baseline|evermemos)
      reset_gateway_plugins
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
  evermemos
  context-saver-only
  token-saver-only
  ilang-only
  concise-only
  slim-prompt
  concise-slim
  token-opt
  lycheemem
  compaction
  compaction-lcm
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
  echo "  baseline, prefix-cache, qmd-only, qmd-vsearch, qmd-query, ccr-only, llmlingua-only, selctx-only, evermemos," >&2
  echo "  context-saver-only, token-saver-only, ilang-only, concise-only, slim-prompt, concise-slim, token-opt," >&2
  echo "  lycheemem, compaction, compaction-lcm" >&2
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
