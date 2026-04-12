#!/usr/bin/env bash
# Register tokenQrusher hooks with the OpenClaw gateway.
#
# Why: ~/.openclaw/skills/tokenqrusher/ only makes SKILL.md available to the agent.
# The gateway loads hook handlers from ~/.openclaw/hooks/<name>/ (real directories).
# Symlinks to paths outside ~/.openclaw/hooks/ are NOT discovered (OpenClaw 2026.3.13).
#
# Required folders from the skill pack (same layout as upstream):
#   token-shared  (shared.js — required by handlers)
#   token-context
#   token-heartbeat
#
# See: experiments/methods/static_compression/tokenqrusher/README.md
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
SKILL_ROOT="${STATE_DIR}/skills/tokenqrusher"
SRC_HOOKS="${SKILL_ROOT}/hooks"
DEST_HOOKS="${STATE_DIR}/hooks"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  tokenQrusher: installing hook packs into ${DEST_HOOKS}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ! -d "${SRC_HOOKS}/token-context" || ! -d "${SRC_HOOKS}/token-heartbeat" || ! -d "${SRC_HOOKS}/token-shared" ]]; then
  echo "  ✖ Missing hook sources under ${SRC_HOOKS}" >&2
  echo "    Copy the skill from: https://github.com/openclaw/skills/tree/main/skills/qsmtco/tokenqrusher" >&2
  exit 1
fi

mkdir -p "${DEST_HOOKS}"

# Replace with fresh copies so upgrades to the skill tree are reflected.
rm -rf "${DEST_HOOKS}/token-shared" "${DEST_HOOKS}/token-context" "${DEST_HOOKS}/token-heartbeat"
cp -a "${SRC_HOOKS}/token-shared" "${SRC_HOOKS}/token-context" "${SRC_HOOKS}/token-heartbeat" "${DEST_HOOKS}/"

echo "  ✓ Copied token-shared, token-context, token-heartbeat"

if command -v tokenqrusher >/dev/null 2>&1; then
  tokenqrusher install --hooks 2>/dev/null || true
fi

openclaw hooks enable token-context 2>/dev/null || true
openclaw hooks enable token-heartbeat 2>/dev/null || true

openclaw gateway restart 2>/dev/null || true
sleep 3
echo "  ✅ Done. Verify: openclaw hooks list"
echo "     Expect token-context + token-heartbeat (Source: managed)."
echo ""
