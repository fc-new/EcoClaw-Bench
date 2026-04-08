#!/usr/bin/env python
"""Generate per-task comparison report across ablation methods."""
import json
import os
import sys

results_root = sys.argv[1] if len(sys.argv) > 1 else "results/raw/pinchbench"
labels = ["baseline", "qmd-only", "qmd-vsearch", "qmd-query", "ccr-only"]

label_files = {}
for label in labels:
    d = os.path.join(results_root, label)
    if os.path.exists(d):
        files = sorted(
            [f for f in os.listdir(d) if f.endswith(".json")],
            key=lambda f: os.path.getmtime(os.path.join(d, f)),
            reverse=True,
        )
        if files:
            label_files[label] = os.path.join(d, files[0])

data = {}
for label, path in label_files.items():
    with open(path) as f:
        data[label] = json.load(f)

model = data.get("baseline", {}).get("model", "unknown")
all_task_ids = [t["task_id"] for t in data["baseline"]["tasks"]]
# First 9 tasks by default, or all if --all flag
max_tasks = len(all_task_ids) if "--all" in sys.argv else 9
task_ids = all_task_ids[:max_tasks]

# Also get task names from frontmatter
task_names = {}
for t in data["baseline"]["tasks"]:
    fm = t.get("frontmatter", {})
    task_names[t["task_id"]] = fm.get("name", t["task_id"])

W = 130
print("=" * W)
print("  {} Per-Task Comparison ({} tasks)".format(model, len(task_ids)))
print("=" * W)

header = "{:<28} {:<14} {:>7} {:>10} {:>10} {:>10} {:>10} {:>5} {:>9} {:>9}".format(
    "Task", "Method", "Score", "Tokens", "Input", "Output", "Cache", "Reqs", "Time(s)", "Cost($)"
)
print(header)
print("-" * W)

for tid in task_ids:
    tname = task_names.get(tid, tid)
    first = True
    for label in labels:
        if label not in data:
            continue
        tasks_map = {t["task_id"]: t for t in data[label]["tasks"]}
        t = tasks_map.get(tid)
        if not t:
            continue
        u = t.get("usage", {})
        g = t.get("grading", {})
        score = g.get("mean", 0)
        tokens = u.get("total_tokens", 0)
        inp = u.get("input_tokens", 0)
        out = u.get("output_tokens", 0)
        cache = u.get("cache_read_tokens", 0)
        reqs = u.get("request_count", 0)
        time_s = t.get("execution_time", 0)
        cost = u.get("cost_usd", 0) or 0

        display_name = tname if first else ""
        row = "{:<28} {:<14} {:>7.4f} {:>10,} {:>10,} {:>10,} {:>10,} {:>5} {:>9.1f} {:>8.4f}$".format(
            display_name, label, score, tokens, inp, out, cache, reqs, time_s, cost
        )
        print(row)
        first = False
    print()

# Summary
print("=" * W)
print("  Summary by Method")
print("=" * W)
for label in labels:
    if label not in data:
        continue
    eff = data[label].get("efficiency", {})
    tasks = data[label].get("tasks", [])
    scores = [float(t["grading"]["mean"]) for t in tasks[:max_tasks]]
    mean_score = sum(scores) / len(scores) if scores else 0
    total_tokens = sum(t.get("usage", {}).get("total_tokens", 0) for t in tasks[:max_tasks])
    total_cost = sum((t.get("usage", {}).get("cost_usd", 0) or 0) for t in tasks[:max_tasks])
    total_time = sum(t.get("execution_time", 0) for t in tasks[:max_tasks])

    row = "  {:<20} score={:.4f}  tokens={:>10,}  cost=${:.4f}  time={:.0f}s".format(
        label, mean_score, total_tokens, total_cost, total_time
    )
    print(row)
print("=" * W)