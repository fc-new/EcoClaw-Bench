# tokenQrusher v2.1.0

> Token optimization for OpenClaw – reduces costs 50–80% via context filtering and heartbeat optimization.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Quick Start

```bash
# Install from ClawHub
clawhub install tokenQrusher

# Restart gateway to enable hooks
openclaw gateway restart

# Test context filter
tokenqrusher context "hi"

# View status
tokenqrusher status
```

## What It Does

tokenQrusher reduces API costs by:

1. **Context Filtering** – Loads only necessary workspace files (up to 99% token reduction for simple messages)
2. **Heartbeat Optimization** – Reduces heartbeat API calls by 75%

This is the simplified, production‑ready core. Non‑functional advisory components (model routing, usage tracking) have been removed.

---

## Features

### Context Hook (`token-context`)

Filters workspace files based on message complexity:

| Complexity | Files Loaded | Savings vs Full Context |
|------------|--------------|------------------------|
| Simple     | SOUL.md, IDENTITY.md | ~99% |
| Standard   | + USER.md             | ~90% |
| Complex    | All 7 files           | 0% (full) |

**Configuration:** `~/.openclaw/hooks/token-context/config.json`

```json
{
  "enabled": true,
  "logLevel": "info",
  "dryRun": false,
  "files": {
    "simple": ["SOUL.md", "IDENTITY.md"],
    "standard": ["SOUL.md", "IDENTITY.md", "USER.md"],
    "complex": ["SOUL.md", "IDENTITY.md", "USER.md", "TOOLS.md", "AGENTS.md", "MEMORY.md", "HEARTBEAT.md"]
  }
}
```

### Heartbeat Optimizer (`token-heartbeat`)

Optimizes heartbeat check schedule:

| Check      | Default | Optimized | Reduction |
|------------|---------|-----------|-----------|
| Email      | 60 min  | 120 min   | 50%       |
| Calendar   | 60 min  | 240 min   | 75%       |
| Weather    | 60 min  | 240 min   | 75%       |
| Monitoring | 30 min  | 120 min   | 75%       |

**Result:** 48 checks/day → 12 checks/day (**75% fewer API calls**)

**Configuration:** `~/.openclaw/hooks/token-heartbeat/config.json`

```json
{
  "enabled": true,
  "intervals": {
    "email": 7200,
    "calendar": 14400,
    "weather": 14400,
    "monitoring": 7200
  },
  "quietHours": { "start": 23, "end": 8 }
}
```

---

## CLI Commands

### `tokenqrusher context <prompt>`

Recommends which context files should be loaded.

```bash
$ tokenqrusher context "hi"
Complexity: simple (confidence: 95%)
Files: SOUL.md, IDENTITY.md
Savings: 71%
```

### `tokenqrusher status [--verbose]`

Shows hook status.

```bash
$ tokenqrusher status
=== tokenQrusher Status ===

Hooks:
  ✓ token-context   (Filters context)
  ✓ token-heartbeat (Optimizes heartbeat)

Optimizer:
  State: IDLE
  Enabled: True
```

### `tokenqrusher install [--hooks] [--all]`

Enables hooks.

```bash
$ tokenqrusher install --hooks
✓ Enabled: token-context
✓ Enabled: token-heartbeat
```

---

## Installation

### From ClawHub (recommended)

```bash
clawhub install tokenQrusher
openclaw gateway restart
```

Hooks are installed automatically. Verify with `openclaw hooks list` – both should show "✓ ready".

### Manual

Clone into `~/.openclaw/workspace/skills/tokenQrusher` and run:

```bash
openclaw hooks enable token-context
openclaw hooks enable token-heartbeat
openclaw gateway restart
```

---

## How It Works

Each hook runs automatically:

- `token-context` → on every `agent:bootstrap` (i.e., each user message) → filters `bootstrapFiles` in the event context.
- `token-heartbeat` → on heartbeat polls → returns `HEARTBEAT_OK` or specific alerts; respects quiet hours and intervals.

No further action required.

---

## Design Principles

- Deterministic: same input → same output
- Pure functions: no hidden side effects
- Immutability: frozen/constant data
- No exceptions for control flow
- Thread‑safe
- Minimal overhead (<1 ms per message)

---

## Troubleshooting

**Hooks not appearing?**

```bash
openclaw hooks list
# Should show token-context and token-heartbeat as ready
```

If missing:

```bash
openclaw hooks enable token-context
openclaw hooks enable token-heartbeat
openclaw gateway restart
```

**Changes not applying?**

Config cache TTL = 60 s. Restart gateway for immediate effect or wait.

---

## Migration from v2.0.x

v2.1.0 removes non‑functional components. If upgrading:

1. Disable and delete old hooks:
   ```bash
   openclaw hooks disable token-model
   openclaw hooks disable token-usage
   openclaw hooks disable token-cron
   rm -rf ~/.openclaw/hooks/token-model
   rm -rf ~/.openclaw/hooks/token-usage
   rm -rf ~/.openclaw/hooks/token-cron
   ```

2. Update the skill:
   ```bash
   clawhub update tokenQrusher
   ```

3. Install remaining hooks:
   ```bash
   tokenqrusher install --hooks
   ```

4. Restart gateway:
   ```bash
   openclaw gateway restart
   ```

**Removed commands:** `tokenqrusher model`, `budget`, `usage`, `optimize`.

---

## License

MIT. See `LICENSE`.

---

## EcoClaw-Bench (this repository)

tokenQrusher is implemented as **OpenClaw hooks** (`token-context`, `token-heartbeat`). It is **not** the same path as EcoClaw’s Python compressors (`ECOCLAW_ENABLE_LLMLINGUA`, `ECOCLAW_ENABLE_SELCTX`), which go through `experiments/tools/baseline-hooks/`.

### 1. Install the skill (pick one)

**OpenClaw CLI version note:** On **2026.3.13**, `openclaw skills` only supports `list` / `info` / `check` — there is **no** `openclaw skills install …`. Newer docs may mention it; if you see `too many arguments for 'skills'`, use **ClawHub CLI** or a manual install instead.

**A — ClawHub CLI**

```bash
npm i -g clawhub
# Registry slug is lowercase; camelCase `tokenQrusher` will 404.
clawhub install qsmtco/tokenqrusher
openclaw gateway restart
```

(`pnpm add -g clawhub` works too. See [ClawHub](https://docs.openclaw.ai/tools/clawhub).)

If you see **`Skill not found`**, the skill may not be published on the registry your CLI uses (API quota text like `remaining: 178/180` is normal — not the cause). Use **manual install (B)** below; source of truth is [openclaw/skills on GitHub](https://github.com/openclaw/skills/tree/main/skills/qsmtco/tokenqrusher).

**B — Manual install from GitHub (works when ClawHub has no entry)**

```bash
mkdir -p ~/.openclaw/skills
git clone --depth 1 https://github.com/openclaw/skills.git /tmp/openclaw-skills-repo
cp -r /tmp/openclaw-skills-repo/skills/qsmtco/tokenqrusher ~/.openclaw/skills/tokenqrusher
rm -rf /tmp/openclaw-skills-repo
```

**Critical (easy to miss):** putting files under `skills/` is **not** enough for hooks. OpenClaw **2026.3.13** discovers hook handlers only from real directories under **`~/.openclaw/hooks/`** (`token-context`, `token-heartbeat`, and **`token-shared`** which both handlers `require`). Symlinks that point **outside** `~/.openclaw/hooks/` are ignored, so `openclaw hooks list` stays at “4/4 bundled” until you copy the hook packs in.

From this repo, run:

```bash
./experiments/scripts/enable_tokenqrusher_hooks.sh
```

That script **`cp -a`**’s the three hook folders from `~/.openclaw/skills/tokenqrusher/hooks/` into `~/.openclaw/hooks/`, then restarts the gateway. You should then see **6/6** hooks including **token-context** and **token-heartbeat** (source: **managed**).

Alternatively: `openclaw hooks install` expects paths that stay inside the hooks directory; the script avoids that by copying the official layout directly.

**C — After install, or if `tokenqrusher` is already on `PATH`**

From this repo, enable hooks and restart the gateway:

```bash
./experiments/scripts/enable_tokenqrusher_hooks.sh
```

Check: `openclaw hooks list` — `token-context` and `token-heartbeat` should be ready.

**Config warnings** about `lycheemem-tools` / `openspace-tools` (plugin id mismatch, disabled) are separate from tokenQrusher; fix or ignore them for this experiment.

### 2. Run PinchBench with hooks applied

Single-agent (writes under `results/raw/pinchbench/tokenqrusher-only/`):

```bash
cd /path/to/EcoClaw-Bench
./experiments/scripts/run_pinchbench_methods.sh --label tokenqrusher-only
```

Multi-agent:

```bash
./experiments/scripts/run_pinchbench_methods_mas.sh --label tokenqrusher-only \
  --agent-config experiments/agent-config/pinchbench_agents.json
```

The `--label tokenqrusher-only` step runs `enable_tokenqrusher_hooks.sh` when the label is entered, then the same OpenClaw config reset as `baseline` (default compaction, extra plugins off), then the benchmark. When the run finishes—or if it fails or is interrupted—`disable_tokenqrusher_hooks.sh` runs so hooks are not left enabled.

---

## Credits

- Design & Implementation: Lieutenant Qrusher (qsmtco)
- Review: Captain JAQ (SMTCo)
- Framework: OpenClaw Team

Built with [OpenClaw](https://github.com/openclaw/openclaw).