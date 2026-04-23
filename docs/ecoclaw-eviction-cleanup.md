# EcoClaw Eviction Cleanup

Date: 2026-04-23

## What was removed

Removed the legacy block-level eviction path that operated on individual history segments and replaced them with stub text such as:

- `[Evicted exec block for ...]`
- `[Evicted context block for ...]`

This path was separate from the canonical task-level eviction path and polluted prompt-prefix analysis.

## Why it was removed

For current EcoClaw eviction experiments we only want to evaluate durable canonical task eviction:

- source of truth: canonical transcript
- trigger: task-state registry `evictableTaskIds`
- action: canonical task-level replacement (`drop` or `pointer_stub`)

The old block-level path introduced a second eviction mechanism with different granularity and different semantics, which made cache behavior hard to interpret.

## Current intended eviction path

Only the following path should remain active during experiments:

1. estimator updates task state
2. registry marks tasks as `evictable`
3. canonical task eviction rewrites canonical history
4. assembled prompt is built from canonical state

## Validation hint

After cleanup, forwarded inputs should no longer contain early legacy stubs like:

- `[Evicted exec block ...]`
- `[Evicted context block ...]`

If these strings appear again, another stale runtime/plugin path is still active.
