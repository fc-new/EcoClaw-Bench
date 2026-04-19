#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# EcoClaw Ablation Runner
#
# Runs PinchBench with exactly ONE EcoClaw module enabled (or none for baseline).
# Results go to results/raw/pinchbench/<label>/ for later comparison.
#
# Usage:
#   ./experiments/scripts/run_pinchbench_methods.sh --label baseline
#   ./experiments/scripts/run_pinchbench_methods.sh --label qmd-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label ccr-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label llmlingua-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label selctx-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label evermemos
#   ./experiments/scripts/run_pinchbench_methods.sh --label context-saver-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label token-saver-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label ilang-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label concise-only
#   ./experiments/scripts/run_pinchbench_methods.sh --label token-opt
#   ./experiments/scripts/run_pinchbench_methods.sh --label agentswing
#   ./experiments/scripts/run_pinchbench_methods.sh --label memobrain
#   ./experiments/scripts/run_pinchbench_methods.sh --label pichay
#
# Or run all methods in sequence:
#   ./experiments/scripts/run_pinchbench_methods.sh --all
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
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --label <baseline|prefix-cache|qmd-only|qmd-vsearch|qmd-query|ccr-only|llmlingua-only|selctx-only|evermemos|context-saver-only|token-saver-only|ilang-only|concise-only|slim-prompt|concise-slim|token-opt|agentswing|memobrain|pichay|lycheemem|compaction|compaction-lcm> [--parallel N]" >&2
      echo "       $0 --all [--parallel N]" >&2
      exit 1
      ;;
  esac
done

import_dotenv
apply_ecoclaw_env

# This runner is for single-agent ablations only.
# Prevent accidental MAS activation from .env (e.g., ECOCLAW_AGENT_CONFIG).
export ECOCLAW_ENABLE_MULTI_AGENT=false
unset ECOCLAW_AGENT_CONFIG || true

# ── Resolve common parameters ────────────────────────────────────────────────

MODEL_LIKE="${MODEL:-${ECOCLAW_MODEL:-kuaipao/gpt-5.4-mini}}"
JUDGE_LIKE="${JUDGE:-${ECOCLAW_JUDGE:-kuaipao/gpt-5.4-mini}}"
RESOLVED_MODEL="$(resolve_model_alias "${MODEL_LIKE}")"
RESOLVED_JUDGE="$(resolve_model_alias "${JUDGE_LIKE}")"
RESOLVED_SUITE="${SUITE:-${ECOCLAW_SUITE:-automated-only}}"
RESOLVED_RUNS="${RUNS:-${ECOCLAW_RUNS:-1}}"
RESOLVED_TIMEOUT="${TIMEOUT_MULTIPLIER:-${ECOCLAW_TIMEOUT_MULTIPLIER:-1.0}}"
RESOLVED_PARALLEL="${PARALLEL:-${ECOCLAW_PARALLEL:-1}}"

# Prefer local in-repo PinchBench runner. Fallback to external skill dir if present.
if [[ -d "${REPO_ROOT}/experiments/dataset/pinchbench/scripts" ]]; then
  BENCH_DIR="${REPO_ROOT}/experiments/dataset/pinchbench"
elif SKILL_DIR="$(resolve_skill_dir 2>/dev/null)"; then
  BENCH_DIR="${SKILL_DIR}"
else
  echo "PinchBench benchmark directory not found." >&2
  echo "Expected one of:" >&2
  echo "  1) ${REPO_ROOT}/experiments/dataset/pinchbench" >&2
  echo "  2) ECOCLAW_SKILL_DIR (or ../skill, ~/skill)" >&2
  exit 1
fi

# ── Cleanup: reset all gateway-level plugins to safe defaults ─────────────────

reset_gateway_plugins() {
  echo "  🔄 Resetting gateway plugins to defaults..."
  openclaw config set plugins.entries.lycheemem-tools.enabled false 2>/dev/null || true
  openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
  openclaw config set plugins.entries.evermemos-openclaw-plugin.enabled false 2>/dev/null || true
  openclaw config set plugins.entries.memobrain-context-engine.enabled false 2>/dev/null || true
  openclaw config set plugins.entries.pichay-context-engine.enabled false 2>/dev/null || true
  openclaw config set plugins.slots.memory memory-core 2>/dev/null || true
  openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
  openclaw gateway restart 2>/dev/null || true
  sleep 3
  echo "  ✅ Gateway plugins reset"
}

# ── Single-label run function ─────────────────────────────────────────────────

run_single() {
  local label="$1"
  local token_opt_enabled=0
  local evermemos_enabled=0
  local agentswing_enabled=0
  local memobrain_enabled=0
  local pichay_enabled=0
  local config_patched=0

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
  export ECOCLAW_ENABLE_CONTEXT_SAVER=0
  export ECOCLAW_ENABLE_TOKEN_SAVER=0
  export ECOCLAW_ENABLE_ILANG=0
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
    evermemos)
      local evermemos_plugin_name="${ECOCLAW_EVERMEMOS_PLUGIN_NAME:-evermemos-openclaw-plugin}"
      local evermemos_plugin_dir="${ECOCLAW_EVERMEMOS_PLUGIN_DIR:-${REPO_ROOT}/experiments/methods/retrieval/EverMemOS-agent_memory/evermemos-openclaw-plugin}"
      local evermemos_base_url="${ECOCLAW_EVERMEMOS_BASE_URL:-http://localhost:1995}"
      local evermemos_user_id="${ECOCLAW_EVERMEMOS_USER_ID:-evermemos-user}"
      local evermemos_group_id="${ECOCLAW_EVERMEMOS_GROUP_ID:-evermemos-group}"
      local evermemos_top_k="${ECOCLAW_EVERMEMOS_TOP_K:-5}"
      local evermemos_retrieve_method="${ECOCLAW_EVERMEMOS_RETRIEVE_METHOD:-hybrid}"
      local evermemos_memory_types="${ECOCLAW_EVERMEMOS_MEMORY_TYPES:-episodic_memory,profile,agent_skill,agent_case}"

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

      recover_stale_openclaw_config_backup
      backup_openclaw_config
      trap 'restore_openclaw_config || true' EXIT
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
      local token_opt_script="${REPO_ROOT}/experiments/methods/static_tuning/openclaw-token-optimization-main/apply-preset.js"
      if [[ ! -f "${token_opt_script}" ]]; then
        echo "Token optimization preset script not found: ${token_opt_script}" >&2
        return 1
      fi
      recover_stale_openclaw_config_backup
      backup_openclaw_config
      trap 'restore_openclaw_config || true' EXIT
      node "${token_opt_script}"
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      token_opt_enabled=1
      config_patched=1
      ;;
    agentswing)
      local agentswing_plugin_name="${ECOCLAW_AGENTSWING_PLUGIN_NAME:-agentswing-context-engine}"
      local agentswing_plugin_dir="${ECOCLAW_AGENTSWING_PLUGIN_DIR:-${REPO_ROOT}/experiments/methods/dynamic_management/agentswing}"
      local agentswing_mode="${ECOCLAW_AGENTSWING_MODE:-adaptive-routing}"
      local agentswing_trigger_mode="${ECOCLAW_AGENTSWING_TRIGGER_MODE:-token-ratio}"
      local agentswing_trigger_ratio="${ECOCLAW_AGENTSWING_TRIGGER_RATIO:-0.4}"
      local agentswing_trigger_turn_count="${ECOCLAW_AGENTSWING_TRIGGER_TURN_COUNT:-10}"
      local agentswing_keep_last_n="${ECOCLAW_AGENTSWING_KEEP_LAST_N:-5}"
      local agentswing_context_window="${ECOCLAW_AGENTSWING_CONTEXT_WINDOW:-0}"
      local agentswing_lookahead_steps="${ECOCLAW_AGENTSWING_LOOKAHEAD_STEPS:-3}"

      if [[ ! -d "${agentswing_plugin_dir}" ]]; then
        echo "AgentSwing plugin dir not found: ${agentswing_plugin_dir}" >&2
        return 1
      fi
      if [[ ! -f "${agentswing_plugin_dir}/openclaw.plugin.json" ]]; then
        echo "AgentSwing openclaw.plugin.json not found: ${agentswing_plugin_dir}/openclaw.plugin.json" >&2
        return 1
      fi
      if [[ ! -f "${OPENCLAW_CONFIG_PATH}" ]]; then
        echo "OpenClaw config not found: ${OPENCLAW_CONFIG_PATH}" >&2
        return 1
      fi
      if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 is required to apply AgentSwing plugin config" >&2
        return 1
      fi

      recover_stale_openclaw_config_backup
      backup_openclaw_config
      trap 'restore_openclaw_config || true' EXIT
      python3 - <<'PY' "${OPENCLAW_CONFIG_PATH}" "${agentswing_plugin_dir}" "${agentswing_plugin_name}" "${agentswing_mode}" "${agentswing_trigger_mode}" "${agentswing_trigger_ratio}" "${agentswing_trigger_turn_count}" "${agentswing_keep_last_n}" "${agentswing_context_window}" "${agentswing_lookahead_steps}"
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
plugin_dir = sys.argv[2]
plugin_name = sys.argv[3]
mode = sys.argv[4]
trigger_mode = sys.argv[5]
trigger_ratio = float(sys.argv[6])
trigger_turn_count = int(sys.argv[7])
keep_last_n = int(sys.argv[8])
context_window = int(sys.argv[9])
lookahead_steps = int(sys.argv[10])

data = json.loads(config_path.read_text(encoding="utf-8"))
plugins = data.setdefault("plugins", {})
load = plugins.setdefault("load", {})
paths = load.setdefault("paths", [])
if plugin_dir not in paths:
    paths.append(plugin_dir)
entries = plugins.setdefault("entries", {})
entry = entries.setdefault(plugin_name, {})
entry["enabled"] = True
entry_cfg = entry.setdefault("config", {})
entry_cfg["mode"] = mode
entry_cfg["triggerMode"] = trigger_mode
entry_cfg["triggerRatio"] = trigger_ratio
entry_cfg["triggerTurnCount"] = trigger_turn_count
entry_cfg["keepLastN"] = keep_last_n
entry_cfg["lookaheadSteps"] = lookahead_steps
if context_window > 0:
    entry_cfg["contextWindow"] = context_window

config_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(config_path)
PY
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      agentswing_enabled=1
      config_patched=1
      ;;
    memobrain)
      local memobrain_plugin_name="${ECOCLAW_MEMOBRAIN_PLUGIN_NAME:-memobrain-context-engine}"
      local memobrain_plugin_dir="${ECOCLAW_MEMOBRAIN_PLUGIN_DIR:-${REPO_ROOT}/experiments/methods/dynamic_management/MemoBrain-main/plugins/memobrain-context-engine}"
      local memobrain_adapter_base_url="${ECOCLAW_MEMOBRAIN_ADAPTER_BASE_URL:-http://127.0.0.1:19002}"
      local memobrain_trigger_mode="${ECOCLAW_MEMOBRAIN_TRIGGER_MODE:-token-ratio}"
      local memobrain_trigger_ratio="${ECOCLAW_MEMOBRAIN_TRIGGER_RATIO:-0.4}"
      local memobrain_trigger_turn_count="${ECOCLAW_MEMOBRAIN_TRIGGER_TURN_COUNT:-10}"
      local memobrain_max_memory_size="${ECOCLAW_MEMOBRAIN_MAX_MEMORY_SIZE:-32768}"
      local memobrain_request_timeout_ms="${ECOCLAW_MEMOBRAIN_REQUEST_TIMEOUT_MS:-30000}"

      if [[ ! -d "${memobrain_plugin_dir}" ]]; then
        echo "MemoBrain plugin dir not found: ${memobrain_plugin_dir}" >&2
        return 1
      fi
      if [[ ! -f "${memobrain_plugin_dir}/openclaw.plugin.json" ]]; then
        echo "MemoBrain openclaw.plugin.json not found: ${memobrain_plugin_dir}/openclaw.plugin.json" >&2
        return 1
      fi
      if [[ ! -f "${OPENCLAW_CONFIG_PATH}" ]]; then
        echo "OpenClaw config not found: ${OPENCLAW_CONFIG_PATH}" >&2
        return 1
      fi
      if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 is required to apply MemoBrain plugin config" >&2
        return 1
      fi
      if ! python3 - <<'PY' "${memobrain_adapter_base_url}"
import sys
import urllib.request
import time

url = sys.argv[1].rstrip("/") + "/health"
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
ok = False
for _ in range(5):
    try:
        with opener.open(url, timeout=3) as resp:
            ok = (resp.status == 200)
            if ok:
                break
    except Exception:
        time.sleep(0.4)
sys.exit(0 if ok else 1)
PY
      then
        echo "MemoBrain adapter is unreachable at ${memobrain_adapter_base_url} (expecting /health)" >&2
        echo "Please start adapter first, e.g. python examples/memobrain_adapter.py --host 127.0.0.1 --port 19002" >&2
        return 1
      fi

      recover_stale_openclaw_config_backup
      backup_openclaw_config
      trap 'restore_openclaw_config || true' EXIT
      python3 - <<'PY' "${OPENCLAW_CONFIG_PATH}" "${memobrain_plugin_dir}" "${memobrain_plugin_name}" "${memobrain_adapter_base_url}" "${memobrain_trigger_mode}" "${memobrain_trigger_ratio}" "${memobrain_trigger_turn_count}" "${memobrain_max_memory_size}" "${memobrain_request_timeout_ms}"
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
plugin_dir = sys.argv[2]
plugin_name = sys.argv[3]
adapter_base_url = sys.argv[4]
trigger_mode = sys.argv[5]
trigger_ratio = float(sys.argv[6])
trigger_turn_count = int(sys.argv[7])
max_memory_size = int(sys.argv[8])
request_timeout_ms = int(sys.argv[9])

data = json.loads(config_path.read_text(encoding="utf-8"))
plugins = data.setdefault("plugins", {})
load = plugins.setdefault("load", {})
paths = load.setdefault("paths", [])
if plugin_dir not in paths:
    paths.append(plugin_dir)
entries = plugins.setdefault("entries", {})
entry = entries.setdefault(plugin_name, {})
entry["enabled"] = True
entry_cfg = entry.setdefault("config", {})
entry_cfg["adapterBaseUrl"] = adapter_base_url
entry_cfg["triggerMode"] = trigger_mode
entry_cfg["triggerRatio"] = trigger_ratio
entry_cfg["triggerTurnCount"] = trigger_turn_count
entry_cfg["maxMemorySize"] = max_memory_size
entry_cfg["requestTimeoutMs"] = request_timeout_ms

config_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(config_path)
PY
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      memobrain_enabled=1
      config_patched=1
      ;;
    pichay)
      local pichay_plugin_name="${ECOCLAW_PICHAY_PLUGIN_NAME:-pichay-context-engine}"
      local pichay_plugin_dir="${ECOCLAW_PICHAY_PLUGIN_DIR:-${REPO_ROOT}/experiments/methods/dynamic_management/pichay-main/plugins/pichay-context-engine}"
      local pichay_adapter_base_url="${ECOCLAW_PICHAY_ADAPTER_BASE_URL:-http://127.0.0.1:19012}"
      local pichay_trigger_mode="${ECOCLAW_PICHAY_TRIGGER_MODE:-token-ratio}"
      local pichay_trigger_ratio="${ECOCLAW_PICHAY_TRIGGER_RATIO:-0.4}"
      local pichay_trigger_turn_count="${ECOCLAW_PICHAY_TRIGGER_TURN_COUNT:-10}"
      local pichay_age_threshold="${ECOCLAW_PICHAY_AGE_THRESHOLD:-4}"
      local pichay_min_evict_size="${ECOCLAW_PICHAY_MIN_EVICT_SIZE:-500}"
      local pichay_preserve_recent="${ECOCLAW_PICHAY_PRESERVE_RECENT:-12}"
      local pichay_min_text_chars="${ECOCLAW_PICHAY_MIN_TEXT_CHARS:-2000}"
      local pichay_max_summary_chars="${ECOCLAW_PICHAY_MAX_SUMMARY_CHARS:-300}"
      local pichay_enable_model_summary="${ECOCLAW_PICHAY_ENABLE_MODEL_SUMMARY:-false}"
      local pichay_request_timeout_ms="${ECOCLAW_PICHAY_REQUEST_TIMEOUT_MS:-30000}"

      if [[ ! -d "${pichay_plugin_dir}" ]]; then
        echo "Pichay plugin dir not found: ${pichay_plugin_dir}" >&2
        return 1
      fi
      if [[ ! -f "${pichay_plugin_dir}/openclaw.plugin.json" ]]; then
        echo "Pichay openclaw.plugin.json not found: ${pichay_plugin_dir}/openclaw.plugin.json" >&2
        return 1
      fi
      if [[ ! -f "${OPENCLAW_CONFIG_PATH}" ]]; then
        echo "OpenClaw config not found: ${OPENCLAW_CONFIG_PATH}" >&2
        return 1
      fi
      if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 is required to apply Pichay plugin config" >&2
        return 1
      fi
      if ! python3 - <<'PY' "${pichay_adapter_base_url}"
import sys
import urllib.request
import time

url = sys.argv[1].rstrip("/") + "/health"
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
ok = False
for _ in range(5):
    try:
        with opener.open(url, timeout=3) as resp:
            ok = (resp.status == 200)
            if ok:
                break
    except Exception:
        time.sleep(0.4)
sys.exit(0 if ok else 1)
PY
      then
        echo "Pichay adapter is unreachable at ${pichay_adapter_base_url} (expecting /health)" >&2
        echo "Please start adapter first, e.g. python -m pichay.openclaw_adapter --host 127.0.0.1 --port 19012" >&2
        return 1
      fi

      recover_stale_openclaw_config_backup
      backup_openclaw_config
      trap 'restore_openclaw_config || true' EXIT
      python3 - <<'PY' "${OPENCLAW_CONFIG_PATH}" "${pichay_plugin_dir}" "${pichay_plugin_name}" "${pichay_adapter_base_url}" "${pichay_trigger_mode}" "${pichay_trigger_ratio}" "${pichay_trigger_turn_count}" "${pichay_age_threshold}" "${pichay_min_evict_size}" "${pichay_preserve_recent}" "${pichay_min_text_chars}" "${pichay_max_summary_chars}" "${pichay_enable_model_summary}" "${pichay_request_timeout_ms}"
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
plugin_dir = sys.argv[2]
plugin_name = sys.argv[3]
adapter_base_url = sys.argv[4]
trigger_mode = sys.argv[5]
trigger_ratio = float(sys.argv[6])
trigger_turn_count = int(sys.argv[7])
age_threshold = int(sys.argv[8])
min_evict_size = int(sys.argv[9])
preserve_recent = int(sys.argv[10])
min_text_chars = int(sys.argv[11])
max_summary_chars = int(sys.argv[12])
enable_model_summary = str(sys.argv[13]).lower() == "true"
request_timeout_ms = int(sys.argv[14])

data = json.loads(config_path.read_text(encoding="utf-8"))
plugins = data.setdefault("plugins", {})
load = plugins.setdefault("load", {})
paths = load.setdefault("paths", [])
if plugin_dir not in paths:
    paths.append(plugin_dir)
entries = plugins.setdefault("entries", {})
entry = entries.setdefault(plugin_name, {})
entry["enabled"] = True
entry_cfg = entry.setdefault("config", {})
entry_cfg["adapterBaseUrl"] = adapter_base_url
entry_cfg["triggerMode"] = trigger_mode
entry_cfg["triggerRatio"] = trigger_ratio
entry_cfg["triggerTurnCount"] = trigger_turn_count
entry_cfg["ageThreshold"] = age_threshold
entry_cfg["minEvictSize"] = min_evict_size
entry_cfg["preserveRecent"] = preserve_recent
entry_cfg["minTextChars"] = min_text_chars
entry_cfg["maxSummaryChars"] = max_summary_chars
entry_cfg["enableModelSummary"] = enable_model_summary
entry_cfg["requestTimeoutMs"] = request_timeout_ms

config_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(config_path)
PY
      openclaw gateway restart 2>/dev/null || true
      sleep 3
      pichay_enabled=1
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
      echo "Valid labels: baseline, prefix-cache, qmd-only, qmd-vsearch, qmd-query, ccr-only, llmlingua-only, selctx-only, evermemos, context-saver-only, token-saver-only, ilang-only, concise-only, slim-prompt, concise-slim, token-opt, agentswing, memobrain, pichay, lycheemem, compaction, compaction-lcm" >&2
      return 1
      ;;
  esac

  # For baseline: ensure compaction is in default mode and all extra plugins disabled
  if [[ "${label}" == "baseline" ]]; then
    openclaw config set agents.defaults.compaction.mode default 2>/dev/null || true
    openclaw config set plugins.entries.lossless-claw.enabled false 2>/dev/null || true
    openclaw config set plugins.entries.lycheemem-tools.enabled false 2>/dev/null || true
    openclaw gateway restart 2>/dev/null || true
    sleep 3
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🧪 Ablation: ${label}"
  echo "  Model: ${RESOLVED_MODEL}"
  echo "  PREFIX_CACHE=${ECOCLAW_ENABLE_PREFIX_CACHE}  QMD=${ECOCLAW_ENABLE_QMD}  CCR=${ECOCLAW_ENABLE_CCR}"
  echo "  LLMLINGUA=${ECOCLAW_ENABLE_LLMLINGUA}  SELCTX=${ECOCLAW_ENABLE_SELCTX}  EVERMEMOS=${evermemos_enabled}  CONTEXT_SAVER=${ECOCLAW_ENABLE_CONTEXT_SAVER}  TOKEN_SAVER=${ECOCLAW_ENABLE_TOKEN_SAVER}  ILANG=${ECOCLAW_ENABLE_ILANG}"
  echo "  CONCISE=${ECOCLAW_ENABLE_CONCISE}  SLIM_PROMPT=${ECOCLAW_ENABLE_SLIM_PROMPT}"
  echo "  TOKEN_OPT=${token_opt_enabled}  AGENTSWING=${agentswing_enabled}  MEMOBRAIN=${memobrain_enabled}  PICHAY=${pichay_enabled}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local output_dir="${REPO_ROOT}/results/raw/pinchbench/${label}"
  mkdir -p "${output_dir}"

  cd "${BENCH_DIR}"
  uv run scripts/benchmark.py \
    --model "${RESOLVED_MODEL}" \
    --judge "${RESOLVED_JUDGE}" \
    --suite "${RESOLVED_SUITE}" \
    --runs "${RESOLVED_RUNS}" \
    --parallel "${RESOLVED_PARALLEL}" \
    --timeout-multiplier "${RESOLVED_TIMEOUT}" \
    --output-dir "${output_dir}" \
    --no-upload

  echo ""
  echo "  ✅ ${label} complete → ${output_dir}"
  echo ""

  if [[ "${config_patched}" == "1" ]]; then
    restore_openclaw_config || true
    trap - EXIT
    openclaw gateway restart 2>/dev/null || true
    sleep 3
  fi

  # Auto-cleanup: disable gateway-level plugins after each run
  case "${label}" in
    lycheemem|compaction|compaction-lcm|baseline)
      reset_gateway_plugins
      ;;
  esac
}

# ── Main ──────────────────────────────────────────────────────────────────────

ALL_LABELS=(baseline prefix-cache qmd-only qmd-vsearch qmd-query ccr-only llmlingua-only selctx-only evermemos context-saver-only token-saver-only ilang-only concise-only slim-prompt concise-slim token-opt agentswing memobrain pichay lycheemem compaction compaction-lcm)

if [[ "${RUN_ALL}" == "true" ]]; then
  echo "Running all ${#ALL_LABELS[@]} ablation experiments..."
  for lbl in "${ALL_LABELS[@]}"; do
    run_single "${lbl}"
  done
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  🎉 All ${#ALL_LABELS[@]} ablation runs complete!"
  echo "  Run compare_pinchbench_ablation.sh to generate the comparison report."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
elif [[ -n "${LABEL}" ]]; then
  run_single "${LABEL}"
else
  echo "Usage: $0 --label <baseline|prefix-cache|qmd-only|qmd-vsearch|qmd-query|ccr-only|llmlingua-only|selctx-only|evermemos|context-saver-only|token-saver-only|ilang-only|concise-only|slim-prompt|concise-slim|token-opt|agentswing|memobrain|pichay|lycheemem|compaction|compaction-lcm> [--parallel N]" >&2
  echo "       $0 --all [--parallel N]" >&2
  exit 1
fi
