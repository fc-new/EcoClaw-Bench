#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Compare ablation results against a baseline.
#
# Two modes:
#   1. Auto mode (default): scan results/raw/pinchbench/<label>/ dirs, pick
#      latest JSON per model, group by model.
#   2. Manual mode: specify JSON files directly via positional args.
#      First file is the baseline; remaining files are compared against it.
#
# Usage:
#   # Auto mode (same as before)
#   ./experiments/scripts/compare_pinchbench_methods.sh
#
#   # Manual mode: pick specific files to compare
#   ./experiments/scripts/compare_pinchbench_methods.sh \
#       results/raw/pinchbench/baseline/0044_gmn-gpt-5-4.json \
#       results/raw/pinchbench/selctx-only/0060_gmn-gpt-5-4.json \
#       results/raw/pinchbench/llmlingua-only/0057_gmn-gpt-5-4.json
#
#   # Manual mode with custom labels
#   ./experiments/scripts/compare_pinchbench_methods.sh \
#       --label baseline:results/raw/pinchbench/baseline/0044_gmn-gpt-5-4.json \
#       --label "selctx v4:results/raw/pinchbench/selctx-only/0060_gmn-gpt-5-4.json"
#
#   # Optional: --report-path <file>
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

REPORT_PATH="${REPO_ROOT}/results/reports/pinchbench_ablation.json"
MANUAL_FILES=()
LABELED_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-path) REPORT_PATH="${2:-}"; shift 2 ;;
    --label) LABELED_FILES+=("${2:-}"); shift 2 ;;
    --help|-h)
      echo "Usage:"
      echo "  $0                                          # Auto mode"
      echo "  $0 file1.json file2.json ...                # Manual mode (first = baseline)"
      echo "  $0 --label name:file.json --label name2:f2  # Manual with custom labels"
      echo "  $0 --report-path out.json                   # Custom report output"
      exit 0
      ;;
    *)
      if [[ -f "$1" ]]; then
        MANUAL_FILES+=("$1")
        shift
      else
        echo "Unknown argument or file not found: $1" >&2
        exit 1
      fi
      ;;
  esac
done

mkdir -p "$(dirname "${REPORT_PATH}")"

RESULTS_ROOT="${REPO_ROOT}/results/raw/pinchbench"

# Build the JSON args for the Python script
# Format: JSON array of {"label": "...", "file": "..."} for manual mode, or empty for auto
MANUAL_JSON="[]"
if [[ ${#LABELED_FILES[@]} -gt 0 ]]; then
  # --label mode: "name:path"
  items=()
  for entry in "${LABELED_FILES[@]}"; do
    label="${entry%%:*}"
    file="${entry#*:}"
    items+=("{\"label\":\"${label}\",\"file\":\"${file}\"}")
  done
  MANUAL_JSON="[$(IFS=,; echo "${items[*]}")]"
elif [[ ${#MANUAL_FILES[@]} -gt 0 ]]; then
  # Positional args mode: first = baseline, rest derive label from parent dir
  items=()
  for i in "${!MANUAL_FILES[@]}"; do
    file="${MANUAL_FILES[$i]}"
    if [[ $i -eq 0 ]]; then
      label="baseline"
    else
      # Derive label from parent directory name
      label="$(basename "$(dirname "${file}")")"
    fi
    items+=("{\"label\":\"${label}\",\"file\":\"${file}\"}")
  done
  MANUAL_JSON="[$(IFS=,; echo "${items[*]}")]"
fi

python - <<'PY' "${RESULTS_ROOT}" "${REPORT_PATH}" "${MANUAL_JSON}"
import json
import pathlib
import statistics
import sys

results_root = pathlib.Path(sys.argv[1])
report_path = pathlib.Path(sys.argv[2])
manual_entries = json.loads(sys.argv[3])

ALL_LABELS = ["baseline", "prefix-cache", "cache-only", "summary-only", "compression-only",
              "retrieval-only", "router-only", "qmd-only", "qmd-vsearch", "qmd-query",
              "ccr-only", "llmlingua-only", "selctx-only", "tokenqrusher-only"]

def extract_metrics(payload):
    scores = [float(t["grading"]["mean"]) for t in payload.get("tasks", [])]
    eff = payload.get("efficiency", {})
    return {
        "model": payload.get("model", "unknown"),
        "run_id": payload.get("run_id", ""),
        "suite": payload.get("suite", ""),
        "mean_score": round(statistics.mean(scores), 6) if scores else 0.0,
        "total_tokens": eff.get("total_tokens", 0),
        "total_input_tokens": eff.get("total_input_tokens", 0),
        "total_output_tokens": eff.get("total_output_tokens", 0),
        "total_cache_read_tokens": sum(
            t.get("usage", {}).get("cache_read_tokens", 0)
            for t in payload.get("tasks", [])
        ),
        "total_cost_usd": eff.get("total_cost_usd", 0.0),
        "score_per_1k_tokens": eff.get("score_per_1k_tokens"),
        "score_per_dollar": eff.get("score_per_dollar"),
        "total_requests": eff.get("total_requests", 0),
        "total_execution_time": eff.get("total_execution_time_seconds", 0),
        "task_count": len(scores),
    }

def fmt_row(label, m, d=None, is_baseline=False):
    """Format a table row with input/output/cache breakdown."""
    score = m["mean_score"]
    inp = m.get("total_input_tokens", 0)
    out = m.get("total_output_tokens", 0)
    cache = m.get("total_cache_read_tokens", 0)
    total = m.get("total_tokens", 0)
    cost = m.get("total_cost_usd") or 0
    time_s = m.get("total_execution_time", 0)
    
    if is_baseline:
        return "  {:<20} {:>8.4f} {:>10} {:>10,} {:>10,} {:>12,} {:>12,} {:>10.4f}$ {:>7.0f}s {:>8}".format(
            label, score, "—", inp, out, cache, total, cost, time_s, "—"
        )
    else:
        ds = d["mean_score_delta"]
        dt = d["time_delta"]
        ssign = "+" if ds >= 0 else ""
        esign = "+" if dt >= 0 else ""
        return "  {:<20} {:>8.4f} {}{:>9.4f} {:>10,} {:>10,} {:>12,} {:>12,} {:>10.4f}$ {:>7.0f}s {}{:>6.0f}s".format(
            label, score, ssign, ds, inp, out, cache, total, cost, time_s, esign, dt
        )

# ── Manual mode ──────────────────────────────────────────────────────────────
if manual_entries:
    print("\n" + "━" * 90)
    print("  📊 Manual Comparison")
    print("━" * 90)

    entries = []
    for e in manual_entries:
        f = pathlib.Path(e["file"])
        if not f.exists():
            print(f"  ❌ File not found: {f}")
            continue
        payload = json.loads(f.read_text(encoding="utf-8"))
        metrics = extract_metrics(payload)
        metrics["file"] = str(f)
        label = e["label"]
        entries.append((label, metrics))
        print(f"  ✅ {label}: {f.name} (model={metrics['model']}, score={metrics['mean_score']:.4f}, tokens={metrics['total_tokens']:,})")

    if len(entries) < 2:
        print("  ❌ Need at least 2 files to compare")
        sys.exit(1)

    baseline_label, baseline = entries[0]

    # Build report
    report = {"mode": "manual", "baseline_label": baseline_label, "entries": [], "deltas": []}
    for label, m in entries:
        report["entries"].append({"label": label, **m})

    # Print table
    print()
    hdr = "  {:<20} {:>8} {:>10} {:>10} {:>10} {:>12} {:>12} {:>10} {:>8} {:>8}".format(
        "Label", "Score", "Δ Score", "Input", "Output", "Cache(read)", "Total Tok", "Cost($)", "Time", "Δ Time"
    )
    print(hdr)
    print("  " + "-" * (len(hdr) - 2))
    print(fmt_row(baseline_label, baseline, is_baseline=True))

    for label, m in entries[1:]:
        d = {
            "mean_score_delta": m["mean_score"] - baseline["mean_score"],
            "time_delta": m.get("total_execution_time", 0) - baseline.get("total_execution_time", 0),
        }
        print(fmt_row(label, m, d))
        b_cost = baseline.get('total_cost_usd') or 0
        m_cost = m.get('total_cost_usd') or 0
        report["deltas"].append({
            "label": label,
            "vs": baseline_label,
            "mean_score_delta": round(d["mean_score_delta"], 6),
            "token_delta": m["total_tokens"] - baseline["total_tokens"],
            "cost_delta": round(m_cost - b_cost, 6),
            "time_delta": round(d["time_delta"], 1),
        })

    print("  " + "=" * (len(hdr) - 2))
    report["generated_at"] = __import__("datetime").datetime.now().isoformat()
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\n📊 Report written to: {report_path}")
    sys.exit(0)

# ── Auto mode ────────────────────────────────────────────────────────────────
NON_BASELINE_LABELS = [l for l in ALL_LABELS if l != "baseline"]

all_results = {}
for label in ALL_LABELS:
    label_dir = results_root / label
    if not label_dir.exists():
        continue
    for f in sorted(label_dir.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True):
        try:
            payload = json.loads(f.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        model = payload.get("model", "unknown")
        if label not in all_results:
            all_results[label] = {}
        if model not in all_results[label]:
            metrics = extract_metrics(payload)
            metrics["file"] = str(f)
            all_results[label][model] = metrics

models_with_baseline = set()
if "baseline" in all_results:
    models_with_baseline = set(all_results["baseline"].keys())

if not models_with_baseline:
    print("❌ No baseline results found!")
    print("   Use manual mode: $0 baseline.json method1.json method2.json")
    sys.exit(1)

full_report = {"mode": "auto", "models": {}}

for model in sorted(models_with_baseline):
    print(f"\n{'━' * 90}")
    print(f"  📊 Model: {model}")
    print(f"{'━' * 90}")

    model_report = {"labels": {}, "baseline": None, "deltas": {}}
    baseline = all_results["baseline"][model]
    model_report["baseline"] = baseline
    model_report["labels"]["baseline"] = baseline
    print(f"  ✅ baseline: score={baseline['mean_score']:.4f}  tokens={baseline['total_tokens']:,}  time={baseline['total_execution_time']:.0f}s  [{baseline['file'].split('/')[-1]}]")

    for label in NON_BASELINE_LABELS:
        if label not in all_results or model not in all_results[label]:
            continue
        metrics = all_results[label][model]
        model_report["labels"][label] = metrics
        print(f"  ✅ {label}: score={metrics['mean_score']:.4f}  tokens={metrics['total_tokens']:,}  time={metrics['total_execution_time']:.0f}s  [{metrics['file'].split('/')[-1]}]")

    for label, metrics in model_report["labels"].items():
        if label == "baseline":
            continue
        model_report["deltas"][label] = {
            "mean_score_delta": round(metrics["mean_score"] - baseline["mean_score"], 6),
            "token_delta": metrics["total_tokens"] - baseline["total_tokens"],
            "cost_delta": round((metrics.get("total_cost_usd") or 0) - (baseline.get("total_cost_usd") or 0), 6),
            "time_delta": round(metrics.get("total_execution_time", 0) - baseline.get("total_execution_time", 0), 1),
        }

    full_report["models"][model] = model_report

    if model_report["deltas"]:
        print()
        hdr = "  {:<20} {:>8} {:>10} {:>10} {:>10} {:>12} {:>12} {:>10} {:>8} {:>8}".format(
            "Label", "Score", "Δ Score", "Input", "Output", "Cache(read)", "Total Tok", "Cost($)", "Time", "Δ Time"
        )
        print(hdr)
        print("  " + "-" * (len(hdr) - 2))
        print(fmt_row("baseline", baseline, is_baseline=True))
        for label in NON_BASELINE_LABELS:
            if label not in model_report["labels"]:
                continue
            m = model_report["labels"][label]
            d = model_report["deltas"][label]
            print(fmt_row(label, m, d))
        print("  " + "=" * (len(hdr) - 2))

full_report["generated_at"] = __import__("datetime").datetime.now().isoformat()
report_path.write_text(json.dumps(full_report, indent=2), encoding="utf-8")
print(f"\n📊 Report written to: {report_path}")
PY