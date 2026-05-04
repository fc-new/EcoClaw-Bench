# EcoClaw-Bench

EcoClaw-Bench is the benchmark and experiment workspace for **EcoClaw**, focused on **token-efficient continual agents** under long-history settings.

The current live method includes:

- `stable-prefix`
- `reduction`
- `tool-result persistence`
- `task-state estimation`
- `decoupled + fifo eviction`

This repository currently does **not** claim a live `compaction` runtime path. Compaction is intentionally excluded from the method description and result claims below.

---

## What Problem We Target

In continual single-session agents, history grows with every task:

- prompt size keeps increasing
- old completed tasks still occupy context
- cache reuse becomes less stable as history structure drifts
- token cost scales poorly over long sessions

Our goal is not just to delete history aggressively.  
The goal is to reduce token cost **while preserving enough structure for later tasks to remain solvable**.

---

## Method Overview

The current EcoClaw runtime relies on three active components:

### 1. Stable Prefix

This keeps the reusable prefix more stable across turns and improves upstream cache reuse.

It does not directly remove history, but it strongly affects:

- cache-hit stability
- input-token variance
- long-session cost behavior

### 2. Reduction

This performs request-level local slimming on expensive prompt content such as:

- repeated reads
- oversized tool payloads
- HTML / exec outputs
- oversized persisted tool results

Reduction addresses **local prompt bloat** before it becomes long-term history cost.

### 3. Task-Level Eviction

EcoClaw maintains a task-aware canonical history with:

- `active`
- `completed`
- `evictable`

Old cold tasks are removed from canonical history once they become evictable.

The most stable version we found is:

- `decoupled + fifo`

meaning:

- the estimator only predicts task progression
- eviction timing is handled by a separate FIFO promotion rule

---

## Why It Works

The method works because it reduces cost at multiple levels rather than relying on a single compression trick.

### Local payload waste is reduced early

Many tokens are spent on content that is not truly useful for future reasoning:

- repeated file reads
- long tool outputs
- bulky HTML
- oversized message payloads

`reduction` trims these local costs before they dominate future prompts.

### History is managed at task granularity

The baseline mostly behaves like one ever-growing dialogue stream.

EcoClaw instead keeps a task-aware canonical history:

- active task content stays
- recently completed task content may stay briefly
- older completed tasks become evictable
- evictable tasks are removed from canonical history

This produces structural savings instead of cosmetic text shortening.

### Completion and eviction timing are decoupled

One of the main findings from our experiments is that it is unstable to let the same small model decide both:

- whether a task is completed
- whether it should already be evicted

The `decoupled + fifo` design narrows the estimator’s job and makes eviction timing much easier to control.

---

## Experimental Settings

We currently use two evaluation settings.

### 1. Isolated

Directory:

- [save/isolated/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/save/isolated)

Characteristics:

- each task runs independently
- no shared long history
- useful for measuring single capability changes

We mainly use this setting to study:

- `stable-prefix` alone
- `reduction` alone
- `stability + reduction`

This answers:

- how much prompt optimization helps without continual-history pressure

### 2. Continual

Directory:

- [save/continual/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/save/continual)

Characteristics:

- all tasks run in one continuous session
- history accumulates over time
- this is the setting that exposes the real history-management problem

This setting has two main branches:

1. reduction baseline line  
   - [save/continual/reduction/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/save/continual/reduction)

2. eviction line  
   - [save/continual/eviction/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/save/continual/eviction)

Within continual evaluation, we run both:

- `top-10`
- `full`

where:

- `top-10` is mainly for fast debugging and curve inspection
- `full` is used for final score/token comparisons

---

## Current Benchmark Coverage

The most complete and reliable results currently come from:

- **PinchBench**

Another benchmark:

- **ClawEval**

has not yet been fully summarized in this README. So the claims below should be interpreted as:

- PinchBench: current main result line
- ClawEval: to be added later

---

## Current Results

### Full Continual Baseline

Reference baseline:

- run `10154`
- score: `81.8%` (`18.8 / 23.0`)
- total tokens: `2,140,641`

### Full Continual EcoClaw

We ran a `batchturn` ablation for continual full evaluation:

- `turnbatch=1` -> `10167`
- `turnbatch=2` -> `10168`
- `turnbatch=3` -> `10169`
- `turnbatch=4` -> `10170`
- `turnbatch=5` -> `10171`

The best current efficiency/quality tradeoff is:

- run `10169`
- configuration: `decoupled + fifo + turnbatch=3`
- score: `85.3%` (`19.6 / 23.0`)
- total tokens: `1,139,456`

Compared with baseline `10154`:

- token reduction: `1,001,185`
- relative reduction: about `46.8%`
- score improvement: `81.8% -> 85.3%`

This is the main result we currently stand behind.

### Accuracy-Oriented Reference

We also observed:

- run `10170`
- `turnbatch=4`
- score: `86.0%`
- total tokens: `1,990,529`

So:

- `turnbatch=4` is a useful accuracy-oriented reference
- but it is not the best efficiency operating point

---

## Why EcoClaw Saves Tokens Compared with Baseline

Relative to the baseline, EcoClaw reduces token cost in four concrete ways:

1. old tasks no longer remain in canonical history indefinitely
2. oversized tool outputs are slimmed or persisted before dominating future prompts
3. stable-prefix handling improves cache reuse continuity
4. decoupled eviction avoids the prompt churn and cache-locality damage seen in the earlier coupled variant

So the gains do **not** come from a single compression trick.
They come from combining:

- cache stability
- local reduction
- task-aware eviction

---

## Current Scope

Included in this README:

- stable-prefix
- reduction
- tool-result persistence
- task-state estimator
- decoupled FIFO eviction

Not included in this README:

- live compaction runtime
- compaction result claims
- future lifecycle-aware reduction redesigns

---

## Repository Layout

Key directories:

- [experiments/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/experiments)  
  benchmark harness, task definitions, and experiment scripts

- [scripts/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/scripts)  
  commonly used launch scripts

- [results/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/results)  
  structured benchmark outputs

- [save/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/save)  
  archived runs and generated artifacts

- [docs/](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/docs)  
  bench-side notes, bug reports, and cleanup records

---

## Reading Guide

For a quick understanding of the project:

1. this README
2. architecture notes under `EcoClaw/docs/architecture/`
3. `docs/experiments/estimator-eviction-decoupling.md`
4. the main scripts under [`scripts/`](/mnt/20t/xubuqiang/EcoClaw/EcoClaw-Bench/scripts)

---

## Current Takeaway

At this stage, the main conclusion is straightforward:

- naive continual history replay is too expensive
- pure coupled eviction is unstable
- `decoupled + fifo` is more controllable
- `stable-prefix + reduction + task-aware eviction` can cut total tokens by nearly half on full continual runs while maintaining or improving benchmark score

That is the current core value proposition of EcoClaw.
