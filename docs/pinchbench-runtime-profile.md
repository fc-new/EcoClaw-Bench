# PinchBench Shared Runtime Profile

This document records the **shared runtime setting** used by our PinchBench experiments.

It is not a method-specific note. It describes the common OpenClaw runtime that our experiment scripts expect before they apply per-run switches such as:

- plugin enabled vs disabled
- eviction enabled vs disabled
- estimator enabled vs disabled
- batch-turn settings

## What this profile installs

The shared runtime installer prepares the following pieces:

- OpenClaw extension: `ecoclaw`
- context engine slot: `ecoclaw-context`
- provider prefix: `ecoclaw/*`
- slash command: `/ecoclaw`
- extra plugin tool: `memory_fault_recover`

These are runtime capabilities available to the experiment harness. Individual runs may still disable parts of this stack through benchmark-side config.

## Built-in OpenClaw tools assumed by PinchBench

Our PinchBench runs currently assume the following built-in tools exist in the runtime:

- `read`
- `edit`
- `write`
- `exec`
- `process`
- `browser`
- `sessions_list`
- `sessions_history`
- `session_status`
- `web_search`
- `web_fetch`
- `image`
- `pdf`
- `memory_search`
- `memory_get`

## Exec allowlist used by the shared PinchBench setting

The shared allowlist currently contains:

- `/usr/bin/find`
- `/usr/bin/ls`
- `/usr/bin/sort`
- `/usr/bin/grep`
- `/usr/bin/head`
- `/usr/bin/tail`
- `/usr/bin/wc`
- `/usr/bin/cut`
- `/usr/bin/tr`
- `/usr/bin/uniq`

This is the common allowlist used for our PinchBench experiment family. It was added to recover directory-discovery failures in:

- `task_15_daily_summary`
- `task_17_email_search`

## One-click installer

Use:

```bash
bash /mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/scripts/install_pinchbench_runtime.sh
```

The installer will:

1. build the local OpenClaw plugin used in our experiments
2. sync it into `~/.openclaw/extensions/ecoclaw/`
3. patch `~/.openclaw/openclaw.json` to the shared PinchBench runtime profile
4. install the shared exec allowlist
5. validate the resulting OpenClaw config

## Scope and intent

This installer is meant to standardize the runtime environment across experiment variants. It does **not** define the final per-run method setting.

Those method-specific switches are still controlled by the benchmark entrypoints, for example:

- baseline runs may disable the plugin
- no-eviction runs may keep estimator/reduction on but disable eviction
- EcoClaw runs may enable the full plugin stack

## Environment overrides

The installer supports environment overrides, including:

- `OPENCLAW_HOME`
- `ECOCLAW_PROXY_BASE_URL`
- `ECOCLAW_PROXY_API_KEY`
- `ECOCLAW_PROXY_PORT`
- `ECOCLAW_ESTIMATOR_ENABLED`
- `ECOCLAW_ESTIMATOR_BASE_URL`
- `ECOCLAW_ESTIMATOR_API_KEY`
- `ECOCLAW_ESTIMATOR_MODEL`
- `ECOCLAW_ESTIMATOR_BATCH_TURNS`
- `ECOCLAW_MODULE_STABILIZER`
- `ECOCLAW_MODULE_POLICY`
- `ECOCLAW_MODULE_REDUCTION`
- `ECOCLAW_MODULE_EVICTION`

Use these only when you intentionally want to change the shared runtime profile.
