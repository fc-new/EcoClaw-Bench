#!/usr/bin/env bash
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
export HOME=/mnt/20t/xubuqiang

export ECOCLAW_BASE_URL='https://kuaipao.ai/v1'
export ECOCLAW_API_KEY=''
export ECOCLAW_MODEL='ecoclaw/gpt-5.4-mini'
export ECOCLAW_JUDGE='ecoclaw/gpt-5.4-mini'

export ECOCLAW_SUITE='all'
export ECOCLAW_RUNS='1'
export ECOCLAW_PARALLEL='1'
export ECOCLAW_SESSION_MODE='continuous'

bash /mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/experiments/scripts/run_pinchbench_baseline.sh \
  --session-mode continuous
