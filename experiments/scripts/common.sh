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
    gpt-5.4-mini) printf '%s/gpt-5.4-mini\n' "${openai_provider_prefix}" ;;
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
    minimax2.7) printf 'minimax/MiniMax-M2.7\n' ;;
    minimax2) printf 'minimax/MiniMax-M2.7\n' ;;
    minimax) printf 'minimax/MiniMax-M2.7\n' ;;
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
  # MiniMax provider support
  if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
    export MINIMAX_API_KEY="${MINIMAX_API_KEY}"
  fi
  # GMN provider support
  if [[ -n "${GMN_API_KEY:-}" ]]; then
    export GMN_API_KEY="${GMN_API_KEY}"
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
  latest_file="$(find "${dir_path}" -maxdepth 1 -type f -name '*.json' -printf '%T@ %p\n' | sort -nr | head -n 1 | awk '{print $2}')"
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

  if ! python3 "${REPO_ROOT}/src/cost/calculate_llm_cost.py" \
    --input "${result_json}" \
    --output "${report_json}" \
    --cache-write-ttl "${cache_write_ttl}" >/dev/null; then
    echo "Cost report generation failed for ${result_json}" >&2
    return 0
  fi

  python3 - <<'PY' "${report_json}"
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

# ---------------------------------------------------------------------------
# Multi-agent config management
# ---------------------------------------------------------------------------

OPENCLAW_CONFIG_PATH="${HOME}/.openclaw/openclaw.json"
OPENCLAW_CONFIG_BACKUP="${HOME}/.openclaw/openclaw.json.bak.bench"

backup_openclaw_config() {
  if [[ -f "${OPENCLAW_CONFIG_BACKUP}" ]]; then
    echo "ERROR: Benchmark config backup already exists: ${OPENCLAW_CONFIG_BACKUP}" >&2
    echo "A previous run may not have restored cleanly. Inspect and remove manually." >&2
    return 1
  fi
  cp "${OPENCLAW_CONFIG_PATH}" "${OPENCLAW_CONFIG_BACKUP}"
  echo "Backed up openclaw.json to ${OPENCLAW_CONFIG_BACKUP}"
}

restore_openclaw_config() {
  if [[ ! -f "${OPENCLAW_CONFIG_BACKUP}" ]]; then
    return 0
  fi
  cp "${OPENCLAW_CONFIG_BACKUP}" "${OPENCLAW_CONFIG_PATH}"
  rm -f "${OPENCLAW_CONFIG_BACKUP}"
  echo "Restored openclaw.json from backup"
}

recover_stale_openclaw_config_backup() {
  if [[ ! -f "${OPENCLAW_CONFIG_BACKUP}" ]]; then
    return 0
  fi
  echo "Found stale benchmark backup at ${OPENCLAW_CONFIG_BACKUP}; restoring it before starting a new run."
  cp "${OPENCLAW_CONFIG_BACKUP}" "${OPENCLAW_CONFIG_PATH}"
  rm -f "${OPENCLAW_CONFIG_BACKUP}"
}

ensure_openclaw_gateway_running() {
  local status_output
  status_output="$(openclaw status 2>/dev/null || true)"

  # Check if gateway is running (even if scope error exists)
  if echo "${status_output}" | grep -q 'Gateway.*local.*18789'; then
    # Gateway process is listening — may have scope warnings but it's operational
    echo "OpenClaw gateway is running on port 18789"
    return 0
  fi

  # Check if systemd service is running
  if echo "${status_output}" | grep -q 'Gateway service.*running'; then
    echo "OpenClaw gateway service is running (systemd)"
    return 0
  fi

  # Gateway is truly not running — start it
  echo "OpenClaw gateway is not running; starting a local gateway..."
  nohup openclaw gateway --force >/tmp/openclaw_gateway.log 2>&1 &
  local gateway_pid=$!
  local attempts=0
  while [[ ${attempts} -lt 20 ]]; do
    if openclaw status 2>/dev/null | grep -q 'Gateway.*local.*18789'; then
      echo "OpenClaw gateway is ready (pid=${gateway_pid})"
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  echo "ERROR: OpenClaw gateway failed to start. See /tmp/openclaw_gateway.log" >&2
  return 1
}

inject_multi_agent_config() {
  local subagent_model="${1:?subagent model is required}"
  local subagent_thinking="${2:-medium}"
  local subagent_max_concurrent="${3:-4}"

  python3 - "${OPENCLAW_CONFIG_PATH}" "${subagent_model}" "${subagent_thinking}" "${subagent_max_concurrent}" <<'INJECT_PY'
import json, sys, copy
config_path, sa_model, sa_thinking, sa_max_concurrent = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

# Deep-merge agents.defaults.subagents
agents = cfg.setdefault("agents", {})
defaults = agents.setdefault("defaults", {})
model_defaults = defaults.setdefault("model", {})
model_defaults["primary"] = sa_model
sa = defaults.setdefault("subagents", {})
sa["model"] = sa_model
sa["thinking"] = sa_thinking
sa["maxConcurrent"] = sa_max_concurrent
sa.setdefault("archiveAfterMinutes", 30)

# Deep-merge tools.subagents.tools.deny
tools = cfg.setdefault("tools", {})
sa_tools = tools.setdefault("subagents", {})
sa_tools_inner = sa_tools.setdefault("tools", {})
deny = sa_tools_inner.get("deny", [])
if "browser" not in deny:
    deny.append("browser")
sa_tools_inner["deny"] = deny

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"Injected multi-agent config: model={sa_model} thinking={sa_thinking} maxConcurrent={sa_max_concurrent}")
INJECT_PY
}

# ---------------------------------------------------------------------------
# OpenSpace MCP management
# ---------------------------------------------------------------------------

OPENSPACE_SERVER_PID_FILE="/tmp/openspace_mcp_bench.pid"

start_openspace_server() {
  # mode: "cold" (default, Phase 1 — build skill library via execute_task)
  #       "hot"  (Phase 2 — reuse skills from cold run via search_skills)
  local mode="${1:-${OPENSPACE_MODE:-cold}}"
  local port="${OPENSPACE_PORT:-${ECOCLAW_OPENSPACE_PORT:-8081}}"
  local workspace="${OPENSPACE_WORKSPACE:-${ECOCLAW_OPENSPACE_WORKSPACE:-}}"
  local skill_dirs="${OPENSPACE_HOST_SKILL_DIRS:-${ECOCLAW_OPENSPACE_SKILL_DIRS:-}}"
  # Expand leading ~ that import_dotenv does not expand (it uses read -r, not eval)
  workspace="${workspace/#\~/$HOME}"
  skill_dirs="${skill_dirs/#\~/$HOME}"

  if [[ -f "${OPENSPACE_SERVER_PID_FILE}" ]]; then
    local existing_pid
    existing_pid="$(cat "${OPENSPACE_SERVER_PID_FILE}")"
    if kill -0 "${existing_pid}" 2>/dev/null; then
      echo "OpenSpace MCP server already running (pid=${existing_pid}, mode=${mode})"
      return 0
    fi
    rm -f "${OPENSPACE_SERVER_PID_FILE}"
  fi

  # ECOCLAW_OPENSPACE_MCP_CMD allows pointing to openspace-mcp in a different Python env
  # e.g. ECOCLAW_OPENSPACE_MCP_CMD=/home/user/anaconda3/bin/openspace-mcp
  local mcp_cmd="${OPENSPACE_MCP_CMD:-${ECOCLAW_OPENSPACE_MCP_CMD:-openspace-mcp}}"

  echo "Starting OpenSpace MCP server on port ${port} (cmd: ${mcp_cmd}, mode: ${mode})..."
  local env_prefix=()
  [[ -n "${workspace}" ]]   && env_prefix+=(OPENSPACE_WORKSPACE="${workspace}")
  [[ -n "${skill_dirs}" ]]  && env_prefix+=(OPENSPACE_HOST_SKILL_DIRS="${skill_dirs}")
  [[ -n "${OPENSPACE_API_KEY:-}" ]]     && env_prefix+=(OPENSPACE_API_KEY="${OPENSPACE_API_KEY}")
  # LLM for OpenSpace's internal grounding agent (execute_task).
  # Set OPENSPACE_MODEL / OPENSPACE_LLM_API_KEY / OPENSPACE_LLM_API_BASE in .env.
  [[ -n "${OPENSPACE_MODEL:-}" ]]       && env_prefix+=(OPENSPACE_MODEL="${OPENSPACE_MODEL}")
  [[ -n "${OPENSPACE_LLM_API_KEY:-}" ]] && env_prefix+=(OPENSPACE_LLM_API_KEY="${OPENSPACE_LLM_API_KEY}")
  [[ -n "${OPENSPACE_LLM_API_BASE:-}" ]] && env_prefix+=(OPENSPACE_LLM_API_BASE="${OPENSPACE_LLM_API_BASE}")
  # Pass mode to the plugin via env so the before_prompt_build hook switches behavior
  env_prefix+=(OPENSPACE_MODE="${mode}")

  env "${env_prefix[@]}" nohup "${mcp_cmd}" \
    --transport streamable-http --host 127.0.0.1 --port "${port}" \
    >/tmp/openspace_mcp_bench.log 2>&1 &
  echo $! > "${OPENSPACE_SERVER_PID_FILE}"

  local attempts=0
  while [[ ${attempts} -lt 20 ]]; do
    if nc -z 127.0.0.1 "${port}" 2>/dev/null; then
      echo "OpenSpace MCP server ready (pid=$(cat "${OPENSPACE_SERVER_PID_FILE}"), port=${port})"
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  echo "ERROR: OpenSpace MCP server failed to start. See /tmp/openspace_mcp_bench.log" >&2
  return 1
}

stop_openspace_server() {
  if [[ ! -f "${OPENSPACE_SERVER_PID_FILE}" ]]; then
    return 0
  fi
  local pid
  pid="$(cat "${OPENSPACE_SERVER_PID_FILE}")"
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    sleep 1
    echo "OpenSpace MCP server stopped (pid=${pid})"
  fi
  rm -f "${OPENSPACE_SERVER_PID_FILE}"
}

register_openspace_plugin() {
  local port="${OPENSPACE_PORT:-${ECOCLAW_OPENSPACE_PORT:-8081}}"
  local plugin_dir
  plugin_dir="$(cd "${REPO_ROOT}/experiments/methods/retrieval/openspace/openclaw-plugin" && pwd)"

  echo "Enabling openspace-tools plugin (port ${port})..."

  # Inject plugin path into plugins.load.paths and enable the plugin entry.
  # NOTE: This version of OpenClaw (2026.3.13) does not have `openclaw mcp set`,
  # so we register via the plugin system instead. The plugin proxies the 4 MCP
  # tools with parameter schemas that match the actual openspace-mcp tool
  # signatures (execute_task/search_skills/fix_skill/upload_skill).
  python3 - "${OPENCLAW_CONFIG_PATH}" "${plugin_dir}" "${port}" <<'INJECT_PY'
import json, sys
config_path, plugin_dir, port = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

# Add plugin dir to plugins.load.paths (deduplicated)
plugins = cfg.setdefault("plugins", {})
load = plugins.setdefault("load", {})
paths = load.get("paths", [])
if plugin_dir not in paths:
    paths.append(plugin_dir)
load["paths"] = paths

# Enable the plugin entry with baseUrl pointing to the running server
entries = plugins.setdefault("entries", {})
entries["openspace-tools"] = {
    "enabled": True,
    "hooks": {
        "allowPromptInjection": True
    },
    "config": {
        "baseUrl": f"http://127.0.0.1:{port}",
        "timeout": 600
    }
}

# tools.profile="coding" creates an allowlist of only core coding tools; plugin
# tools registered via api.registerTool() are not in that list and are silently
# filtered out before the LLM sees them.
# tools.alsoAllow appends to the profile allowlist (valid because tools.allow is
# not set — setting both allow+alsoAllow is an error). "group:plugins" expands
# to all currently-loaded plugin tool names at runtime.
tools_cfg = cfg.setdefault("tools", {})
tools_cfg["alsoAllow"] = ["group:plugins"]

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"Registered openspace-tools plugin (dir={plugin_dir}, port={port}), added group:plugins to tools.alsoAllow")
INJECT_PY
}

unregister_openspace_plugin() {
  echo "Disabling openspace-tools plugin..."
  openclaw config set plugins.entries.openspace-tools.enabled false 2>/dev/null || true
  # Remove the group:plugins alsoAllow added for OpenSpace so other runs are not affected
  openclaw config unset tools.alsoAllow 2>/dev/null || true
}

inject_agent_config_from_file() {
  local agent_config_json="${1:?agent config JSON file is required}"
  local skills_dir="${2:-}"

  if [[ ! -f "${agent_config_json}" ]]; then
    echo "ERROR: Agent config file not found: ${agent_config_json}" >&2
    return 1
  fi

python3 - "${OPENCLAW_CONFIG_PATH}" "${agent_config_json}" "${skills_dir}" <<'INJECT_PY'
import json
import sys

config_path, agent_config_path, skills_dir = sys.argv[1], sys.argv[2], sys.argv[3]

with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)
with open(agent_config_path, "r", encoding="utf-8") as f:
    ac = json.load(f)

src_agents = ac.get("agents", {})
src_agent_list = src_agents.get("list", [])
default_agent = None
for entry in src_agent_list:
    if entry.get("default") or entry.get("id") == "coordinator":
        default_agent = entry
        break
if default_agent is None and src_agent_list:
    default_agent = src_agent_list[0]
default_agent_model = default_agent.get("model") if isinstance(default_agent, dict) else None

if "agents" in ac:
    dst_agents = cfg.setdefault("agents", {})
    if "defaults" in src_agents:
        dst_defaults = dst_agents.setdefault("defaults", {})
        for dk, dv in src_agents["defaults"].items():
            if isinstance(dv, dict):
                dst_defaults.setdefault(dk, {}).update(dv)
            else:
                dst_defaults[dk] = dv
    if default_agent_model:
        dst_defaults = dst_agents.setdefault("defaults", {})
        dst_defaults.setdefault("model", {})["primary"] = default_agent_model
    if "list" in src_agents:
        dst_agents["list"] = src_agents["list"]

if "tools" in ac:
    dst_tools = cfg.setdefault("tools", {})
    for tk, tv in ac["tools"].items():
        if isinstance(tv, dict):
            existing = dst_tools.setdefault(tk, {})
            if isinstance(existing, dict):
                for inner_k, inner_v in tv.items():
                    if isinstance(inner_v, dict) and isinstance(existing.get(inner_k), dict):
                        existing[inner_k].update(inner_v)
                    else:
                        existing[inner_k] = inner_v
            else:
                dst_tools[tk] = tv
        else:
            dst_tools[tk] = tv

if "commands" in ac:
    dst_commands = cfg.setdefault("commands", {})
    dst_commands.update(ac["commands"])

if skills_dir:
    skills_cfg = cfg.setdefault("skills", {})
    load_cfg = skills_cfg.setdefault("load", {})
    extra_dirs = load_cfg.get("extraDirs", [])
    if skills_dir not in extra_dirs:
        extra_dirs.append(skills_dir)
    load_cfg["extraDirs"] = extra_dirs

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")

agent_ids = [a.get("id", "?") for a in ac.get("agents", {}).get("list", [])]
print(f"Injected agent config from {agent_config_path}: agents={agent_ids}")
if skills_dir:
    print(f"Added skills extraDir: {skills_dir}")
INJECT_PY
}
