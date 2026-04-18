#!/usr/bin/env bash
set -euo pipefail

# Install (or reinstall) the AgentSwing context engine plugin into OpenClaw.
# Usage: bash experiments/scripts/install_agentswing_plugin.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN_DIR="${REPO_ROOT}/experiments/plugins/agentswing-context-engine"

# Unset proxy (common issue in this environment)
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy 2>/dev/null || true

if [[ ! -d "${PLUGIN_DIR}" ]]; then
  echo "ERROR: Plugin directory not found: ${PLUGIN_DIR}" >&2
  exit 1
fi

# Build TypeScript if dist/ is missing or source is newer
if [[ ! -f "${PLUGIN_DIR}/dist/index.js" ]] || \
   [[ "${PLUGIN_DIR}/index.ts" -nt "${PLUGIN_DIR}/dist/index.js" ]] || \
   [[ "${PLUGIN_DIR}/src/engine.ts" -nt "${PLUGIN_DIR}/dist/src/engine.js" ]]; then
  echo "Building plugin TypeScript..."

  # Ensure @types/node is available (copy from global if needed)
  if [[ ! -d "${PLUGIN_DIR}/node_modules/@types/node" ]]; then
    GLOBAL_TYPES="$(npm root -g)/@types/node"
    if [[ -d "${GLOBAL_TYPES}" ]]; then
      mkdir -p "${PLUGIN_DIR}/node_modules/@types"
      cp -r "${GLOBAL_TYPES}" "${PLUGIN_DIR}/node_modules/@types/node"
    else
      echo "WARNING: @types/node not found globally. Install with: npm install -g @types/node" >&2
    fi
  fi

  cd "${PLUGIN_DIR}" && tsc
  echo "Build complete."
fi

# Install into OpenClaw (force + bypass dangerous code check for env+fetch in summarizer)
echo "Installing plugin into OpenClaw..."
cd "${PLUGIN_DIR}"
openclaw plugins install . --force --dangerously-force-unsafe-install 2>&1
echo ""
echo "Plugin installed. Restart the gateway to load it."
