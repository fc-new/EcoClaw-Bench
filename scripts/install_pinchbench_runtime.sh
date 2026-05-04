#!/usr/bin/env bash
set -euo pipefail

BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ECOCLAW_ROOT="${BENCH_ROOT}/../EcoClaw"
PLUGIN_DIR="${ECOCLAW_ROOT}/packages/openclaw-plugin"

OPENCLAW_HOME="${OPENCLAW_HOME:-/mnt/20t/xubuqiang/.openclaw}"
RUNTIME_EXT_DIR="${OPENCLAW_HOME}/extensions/ecoclaw"
CONFIG_PATH="${OPENCLAW_HOME}/openclaw.json"
APPROVALS_PRIMARY="${OPENCLAW_HOME}/exec-approvals.json"
APPROVALS_SECONDARY="${OPENCLAW_HOME}/.openclaw/exec-approvals.json"

ECOCLAW_PROXY_BASE_URL="${ECOCLAW_PROXY_BASE_URL:-https://kuaipao.ai/v1}"
ECOCLAW_PROXY_API_KEY="${ECOCLAW_PROXY_API_KEY:-sk-Nf0gcBreOAX9tt0ruwccdpGXyDydIHHXat9e52HByWqLH40g}"
ECOCLAW_PROXY_PORT="${ECOCLAW_PROXY_PORT:-17668}"

ECOCLAW_ESTIMATOR_ENABLED="${ECOCLAW_ESTIMATOR_ENABLED:-true}"
ECOCLAW_ESTIMATOR_BASE_URL="${ECOCLAW_ESTIMATOR_BASE_URL:-https://www.dmxapi.cn/v1}"
ECOCLAW_ESTIMATOR_API_KEY="${ECOCLAW_ESTIMATOR_API_KEY:-sk-0duFL4XjtPuKqFnyUck61ffmFyMgsM7YQWcm7LbWxNZsNDoU}"
ECOCLAW_ESTIMATOR_MODEL="${ECOCLAW_ESTIMATOR_MODEL:-qwen3.5-35b-a3b}"
ECOCLAW_ESTIMATOR_BATCH_TURNS="${ECOCLAW_ESTIMATOR_BATCH_TURNS:-1}"
ECOCLAW_ESTIMATOR_INPUT_MODE="${ECOCLAW_ESTIMATOR_INPUT_MODE:-completed_summary_plus_active_turns}"

ECOCLAW_MODULE_STABILIZER="${ECOCLAW_MODULE_STABILIZER:-true}"
ECOCLAW_MODULE_POLICY="${ECOCLAW_MODULE_POLICY:-true}"
ECOCLAW_MODULE_REDUCTION="${ECOCLAW_MODULE_REDUCTION:-true}"
ECOCLAW_MODULE_EVICTION="${ECOCLAW_MODULE_EVICTION:-true}"

ECOCLAW_EVICTION_POLICY="${ECOCLAW_EVICTION_POLICY:-lru}"
ECOCLAW_EVICTION_MIN_BLOCK_CHARS="${ECOCLAW_EVICTION_MIN_BLOCK_CHARS:-16}"
ECOCLAW_EVICTION_REPLACEMENT_MODE="${ECOCLAW_EVICTION_REPLACEMENT_MODE:-pointer_stub}"

ECOCLAW_REDUCTION_ENGINE="${ECOCLAW_REDUCTION_ENGINE:-layered}"
ECOCLAW_REDUCTION_TRIGGER_MIN_CHARS="${ECOCLAW_REDUCTION_TRIGGER_MIN_CHARS:-2200}"
ECOCLAW_REDUCTION_MAX_TOOL_CHARS="${ECOCLAW_REDUCTION_MAX_TOOL_CHARS:-1200}"

echo "[pinchbench-install] bench_root=${BENCH_ROOT}"
echo "[pinchbench-install] ecoclaw_root=${ECOCLAW_ROOT}"
echo "[pinchbench-install] openclaw_home=${OPENCLAW_HOME}"

mkdir -p "${RUNTIME_EXT_DIR}/dist"
mkdir -p "$(dirname "${APPROVALS_PRIMARY}")" "$(dirname "${APPROVALS_SECONDARY}")"

echo "[pinchbench-install] building shared PinchBench runtime extension..."
pnpm -C "${PLUGIN_DIR}" build

echo "[pinchbench-install] syncing shared runtime extension..."
cp "${PLUGIN_DIR}/dist/index.js" "${RUNTIME_EXT_DIR}/dist/index.js"
cp "${PLUGIN_DIR}/dist/index.js.map" "${RUNTIME_EXT_DIR}/dist/index.js.map"
cp "${PLUGIN_DIR}/dist/semantic-llmlingua2-worker.py" "${RUNTIME_EXT_DIR}/dist/semantic-llmlingua2-worker.py"
cp "${PLUGIN_DIR}/openclaw.plugin.json" "${RUNTIME_EXT_DIR}/openclaw.plugin.json"

cmp -s "${PLUGIN_DIR}/dist/index.js" "${RUNTIME_EXT_DIR}/dist/index.js"
cmp -s "${PLUGIN_DIR}/openclaw.plugin.json" "${RUNTIME_EXT_DIR}/openclaw.plugin.json"

echo "[pinchbench-install] patching shared PinchBench runtime config..."
CONFIG_PATH="${CONFIG_PATH}" python - <<'PY'
import json
import os
from pathlib import Path

def env_bool(name: str, default: str) -> bool:
    return os.environ.get(name, default).strip().lower() in {"1", "true", "yes", "on"}

config_path = Path(os.environ["CONFIG_PATH"])
if config_path.exists():
    data = json.loads(config_path.read_text())
else:
    data = {}

plugins = data.setdefault("plugins", {})
entries = plugins.setdefault("entries", {})
slots = plugins.setdefault("slots", {})
ecoclaw = entries.setdefault("ecoclaw", {})
ecoclaw["enabled"] = True
cfg = ecoclaw.setdefault("config", {})
cfg["enabled"] = True
cfg["proxyAutostart"] = True
cfg["proxyPort"] = int(os.environ["ECOCLAW_PROXY_PORT"])
cfg["proxyBaseUrl"] = os.environ["ECOCLAW_PROXY_BASE_URL"]
cfg["proxyApiKey"] = os.environ["ECOCLAW_PROXY_API_KEY"]
cfg["modules"] = {
    "stabilizer": env_bool("ECOCLAW_MODULE_STABILIZER", "true"),
    "policy": env_bool("ECOCLAW_MODULE_POLICY", "true"),
    "reduction": env_bool("ECOCLAW_MODULE_REDUCTION", "true"),
    "eviction": env_bool("ECOCLAW_MODULE_EVICTION", "true"),
}
cfg["eviction"] = {
    "enabled": env_bool("ECOCLAW_MODULE_EVICTION", "true"),
    "policy": os.environ["ECOCLAW_EVICTION_POLICY"],
    "minBlockChars": int(os.environ["ECOCLAW_EVICTION_MIN_BLOCK_CHARS"]),
    "replacementMode": os.environ["ECOCLAW_EVICTION_REPLACEMENT_MODE"],
}
cfg["reduction"] = {
    "engine": os.environ["ECOCLAW_REDUCTION_ENGINE"],
    "triggerMinChars": int(os.environ["ECOCLAW_REDUCTION_TRIGGER_MIN_CHARS"]),
    "maxToolChars": int(os.environ["ECOCLAW_REDUCTION_MAX_TOOL_CHARS"]),
    "passes": {
        "repeatedReadDedup": True,
        "toolPayloadTrim": False,
        "htmlSlimming": True,
        "execOutputTruncation": True,
        "agentsStartupOptimization": True,
    },
    "passOptions": {},
}
cfg["taskStateEstimator"] = {
    "enabled": env_bool("ECOCLAW_ESTIMATOR_ENABLED", "true"),
    "baseUrl": os.environ["ECOCLAW_ESTIMATOR_BASE_URL"],
    "apiKey": os.environ["ECOCLAW_ESTIMATOR_API_KEY"],
    "model": os.environ["ECOCLAW_ESTIMATOR_MODEL"],
    "requestTimeoutMs": 60000,
    "batchTurns": int(os.environ["ECOCLAW_ESTIMATOR_BATCH_TURNS"]),
    "evictionLookaheadTurns": 3,
    "inputMode": os.environ["ECOCLAW_ESTIMATOR_INPUT_MODE"],
}

for stale_key in ("proxyMode", "hooks", "contextEngine", "compaction"):
    cfg.pop(stale_key, None)

slots["contextEngine"] = "ecoclaw-context"
config_path.write_text(json.dumps(data, indent=2) + "\n")
PY

echo "[pinchbench-install] installing shared exec allowlist..."
APPROVALS_PRIMARY="${APPROVALS_PRIMARY}" APPROVALS_SECONDARY="${APPROVALS_SECONDARY}" python - <<'PY'
import json
import os
import secrets
from pathlib import Path

allowlist = [
    {"id": "usr_bin_find", "pattern": "/usr/bin/find"},
    {"id": "usr_bin_ls", "pattern": "/usr/bin/ls"},
    {"id": "usr_bin_sort", "pattern": "/usr/bin/sort"},
    {"id": "usr_bin_grep", "pattern": "/usr/bin/grep"},
    {"id": "usr_bin_head", "pattern": "/usr/bin/head"},
    {"id": "usr_bin_tail", "pattern": "/usr/bin/tail"},
    {"id": "usr_bin_wc", "pattern": "/usr/bin/wc"},
    {"id": "usr_bin_cut", "pattern": "/usr/bin/cut"},
    {"id": "usr_bin_tr", "pattern": "/usr/bin/tr"},
    {"id": "usr_bin_uniq", "pattern": "/usr/bin/uniq"},
]

for env_name in ("APPROVALS_PRIMARY", "APPROVALS_SECONDARY"):
    path = Path(os.environ[env_name])
    if path.exists():
        try:
            data = json.loads(path.read_text())
        except Exception:
            data = {}
    else:
        data = {}
    data["version"] = 1
    socket_cfg = data.setdefault("socket", {})
    socket_cfg["path"] = str(path.with_suffix(".sock"))
    socket_cfg["token"] = socket_cfg.get("token") or secrets.token_urlsafe(24)
    data["defaults"] = data.get("defaults") or {}
    agents = data.setdefault("agents", {})
    wildcard = agents.setdefault("*", {})
    wildcard["allowlist"] = allowlist
    path.write_text(json.dumps(data, indent=2) + "\n")
PY

echo "[pinchbench-install] validating shared runtime config..."
HOME="$(dirname "${OPENCLAW_HOME}")" OPENCLAW_CONFIG_PATH="${CONFIG_PATH}" openclaw config validate

echo
echo "[pinchbench-install] shared PinchBench runtime profile installed:"
echo "  extension: ecoclaw"
echo "  context engine slot: ecoclaw-context"
echo "  provider prefix: ecoclaw/*"
echo "  command: /ecoclaw"
echo "  extra plugin tool: memory_fault_recover"
echo "  assumed built-ins: read edit write exec process browser sessions_* web_search web_fetch image pdf memory_search memory_get"
echo "  shared exec allowlist: find ls sort grep head tail wc cut tr uniq"
echo
echo "[pinchbench-install] done."
