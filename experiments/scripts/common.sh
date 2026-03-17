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
  if [[ "${model_like}" == */* ]]; then
    printf '%s\n' "${model_like}"
    return 0
  fi

  case "${model_like}" in
    gpt-oss-20b) printf 'openai/gpt-oss-20b\n' ;;
    gpt-oss-120b) printf 'openai/gpt-oss-120b\n' ;;
    gpt-5-nano) printf 'openai/gpt-5-nano\n' ;;
    gpt-5-mini) printf 'openai/gpt-5-mini\n' ;;
    gpt-5) printf 'openai/gpt-5\n' ;;
    gpt-5-chat) printf 'openai/gpt-5-chat\n' ;;
    gpt-4.1-nano) printf 'openai/gpt-4.1-nano\n' ;;
    gpt-4.1-mini) printf 'openai/gpt-4.1-mini\n' ;;
    gpt-4.1) printf 'openai/gpt-4.1\n' ;;
    gpt-4o-mini) printf 'openai/gpt-4o-mini\n' ;;
    gpt-4o) printf 'openai/gpt-4o\n' ;;
    o1) printf 'openai/o1\n' ;;
    o1-mini) printf 'openai/o1-mini\n' ;;
    o1-pro) printf 'openai/o1-pro\n' ;;
    o3-mini) printf 'openai/o3-mini\n' ;;
    o3) printf 'openai/o3\n' ;;
    o4-mini) printf 'openai/o4-mini\n' ;;
    claude-3.5-sonnet) printf 'openrouter/anthropic/claude-3.5-sonnet\n' ;;
    claude-3.5-haiku) printf 'openrouter/anthropic/claude-3.5-haiku\n' ;;
    claude-3.7-sonnet) printf 'openrouter/anthropic/claude-3.7-sonnet\n' ;;
    claude-sonnet-4) printf 'openrouter/anthropic/claude-sonnet-4\n' ;;
    claude-opus-4.1) printf 'openrouter/anthropic/claude-opus-4.1\n' ;;
    claude-haiku-4.5) printf 'openrouter/anthropic/claude-haiku-4.5\n' ;;
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
