#!/usr/bin/env bash
# Remove tokenQrusher hook packs from ~/.openclaw/hooks and restart the gateway.
# Pair with enable_tokenqrusher_hooks.sh (PinchBench tokenqrusher-only runs).
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
DEST_HOOKS="${STATE_DIR}/hooks"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  tokenQrusher: removing hooks from ${DEST_HOOKS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

openclaw hooks disable token-context 2>/dev/null || true
openclaw hooks disable token-heartbeat 2>/dev/null || true

rm -rf "${DEST_HOOKS}/token-shared" "${DEST_HOOKS}/token-context" "${DEST_HOOKS}/token-heartbeat"

openclaw gateway restart 2>/dev/null || true
sleep 3
echo "  ✅ tokenQrusher hooks removed."
echo ""
