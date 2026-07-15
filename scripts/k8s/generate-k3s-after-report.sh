#!/usr/bin/env bash
# Generate Phase 9 before/after validation report (markdown).
#
# Usage:
#   BASELINE_JSON=deploy/.local/logs/k3s-baseline/baseline-20260709-pre.json \
#   AFTER_JSON=deploy/.local/logs/k3s-baseline/baseline-20260709-post.json \
#   SCENARIOS_JSON=deploy/.local/logs/k3s-validation/scenarios_*.json \
#     ./scripts/k8s/generate-k3s-after-report.sh \
#     > docs/observability/k3s-bottleneck-after-report.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
BASELINE_JSON="${BASELINE_JSON:-}"
AFTER_JSON="${AFTER_JSON:-}"
SCENARIOS_JSON="${SCENARIOS_JSON:-}"
PHASE8_DEFERRED="${PHASE8_DEFERRED:-1}"
OUT_PATH="${REPORT_PATH:-}"

if [[ -z "${AFTER_JSON}" ]]; then
  AFTER_JSON="$(ls -t "${CXADO_ARTIFACTS_DIR}"/k3s-baseline/baseline-*.json 2>/dev/null | head -1 || true)"
fi
if [[ -z "${BASELINE_JSON}" ]]; then
  BASELINE_JSON="$(ls -t "${CXADO_ARTIFACTS_DIR}"/k3s-baseline/baseline-*.json 2>/dev/null | tail -1 || true)"
fi
if [[ -z "${SCENARIOS_JSON}" ]]; then
  SCENARIOS_JSON="$(ls -t "${CXADO_ARTIFACTS_DIR}"/k3s-validation/scenarios_*.json 2>/dev/null | head -1 || true)"
fi

export ROOT BASELINE_JSON AFTER_JSON SCENARIOS_JSON PHASE8_DEFERRED
python3 <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["ROOT"])
baseline_path = os.environ.get("BASELINE_JSON", "")
after_path = os.environ.get("AFTER_JSON", "")
scenarios_path = os.environ.get("SCENARIOS_JSON", "")
phase8_deferred = os.environ.get("PHASE8_DEFERRED", "1") == "1"


def load_snap(path: str):
    if not path or not Path(path).is_file():
        return None
    return json.loads(Path(path).read_text())


def find_result(snap, qid):
    if not snap:
        return None
    for row in snap.get("results", []):
        if row.get("id") == qid:
            return row
    return None


def scalar_value(result):
    if not result or result.get("status") != "success":
        return None
    data = result.get("data") or {}
    res = data.get("result") or []
    if not res:
        return None
    val = res[0].get("value")
    if isinstance(val, list) and len(val) == 2:
        return val[1]
    return None


def vector_count(result):
    if not result or result.get("status") != "success":
        return 0
    return len((result.get("data") or {}).get("result") or [])


def up_count(snap, job_pattern):
    result = find_result(snap, "scrape_up")
    if not result:
        return None
    count = 0
    for row in (result.get("data") or {}).get("result") or []:
        job = row.get("metric", {}).get("job", "")
        val = row.get("value", [None, "0"])[1]
        if job_pattern in job or (job_pattern == "egregore-worker" and job == "egregore-worker"):
            if val == "1":
                count += 1
    return count


baseline = load_snap(baseline_path)
after = load_snap(after_path)
scenarios = load_snap(scenarios_path) if scenarios_path else None

blocking_fails = []
warnings = []

checks = [
    ("1 Worker scrape", "egregore_worker_scrape_up", "blocking", lambda v: int(v or 0) >= 1),
    ("2 ti_search success (7d)", "ti_search_success_7d", "blocking", lambda v: v is not None and float(v) > 0),
    ("3 Failure reasons", "worker_failures_by_persona_reason_7d", "blocking", lambda v: int(v or 0) > 0),
    ("5 Pending pods", "pending_egregore", "blocking", lambda v: int(v or 0) == 0),
    ("4 soc p95 (7d)", "worker_p95_7d", "recommended", lambda v: v is None or float(v) < 600),
    ("7 GPU DCGM up", "gpu_dcgm_up", "recommended", lambda v: v == "1" or v == 1),
    ("7 GPU node up", "gpu_node_up", "recommended", lambda v: v == "1" or v == 1),
]

rows = []
for label, qid, tier, fn in checks:
    if qid in ("worker_failures_by_reason_7d", "worker_failures_by_persona_reason_7d", "pending_egregore", "egregore_worker_scrape_up"):
        b = vector_count(find_result(baseline, qid))
        a = vector_count(find_result(after, qid))
    else:
        b = scalar_value(find_result(baseline, qid))
        a = scalar_value(find_result(after, qid))
    try:
        ok = fn(a)
    except (TypeError, ValueError):
        ok = False
    verdict = "PASS" if ok else ("WARN" if tier == "recommended" else "FAIL")
    if verdict == "FAIL":
        blocking_fails.append(label)
    elif verdict == "WARN":
        warnings.append(label)
    rows.append((label, tier, b, a, verdict))

if phase8_deferred:
    rows.append(("8 vLLM shaping", "deferred", "—", "skipped", "DEFERRED"))
else:
    rows.append(("8 vLLM shaping", "recommended", scalar_value(find_result(baseline, "vllm_e2e_p95_1h")),
                 scalar_value(find_result(after, "vllm_e2e_p95_1h")), "WARN"))

scenario_rows = []
scenario_fail = False
if scenarios:
    for s in scenarios.get("scenarios", []):
        scenario_rows.append(s)
        if s.get("status") == "fail":
            scenario_fail = True
            if s.get("id") == "S2":
                blocking_fails.append("S2 ti_search scenario")

if blocking_fails or scenario_fail:
    verdict = "FAIL"
elif warnings or any(s.get("status") == "conditional" for s in scenario_rows):
    verdict = "CONDITIONAL"
else:
    verdict = "PASS"

now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
lines = [
    "# K3s bottleneck — after report (Phase 9)",
    "",
    f"**Generated:** {now}  ",
    f"**Verdict:** **{verdict}**",
    "",
    "> Auto-generated by `scripts/k8s/generate-k3s-after-report.sh`. Do not hand-edit numbers.",
    "",
    "## Executive summary",
    "",
]
if verdict == "PASS":
    lines += [
        "- Blocking SLOs met after Phases 1–7 deploy.",
        "- Agent scenarios S1–S3 completed or documented.",
        "- Phase 8 (vLLM shaping) deferred by choice.",
    ]
elif verdict == "CONDITIONAL":
    lines += [
        "- Blocking infra/tool gates passed with documented warnings.",
        f"- Warnings: {', '.join(warnings) or 'see matrix'}.",
        "- Phase 8 deferred.",
    ]
else:
    lines += [
        f"- Blocking failures: {', '.join(blocking_fails)}.",
        "- See matrix and scenario logs under `deploy/.local/logs/k3s-validation/`.",
    ]

lines += [
    "",
    "## Deploy context",
    "",
    f"| Field | Value |",
    f"|-------|-------|",
    f"| Baseline JSON | `{baseline_path or 'n/a'}` |",
    f"| After JSON | `{after_path or 'n/a'}` |",
    f"| Scenarios JSON | `{scenarios_path or 'n/a'}` |",
    f"| Phase 8 | {'deferred' if phase8_deferred else 'included'} |",
    "",
    "## Metrics matrix",
    "",
    "| Check | Tier | Before | After | Verdict |",
    "|-------|------|--------|-------|---------|",
]
for label, tier, b, a, v in rows:
    lines.append(f"| {label} | {tier} | {b if b is not None else '—'} | {a if a is not None else '—'} | {v} |")

lines += [
    "",
    "## Scenarios",
    "",
    "| ID | Status | Investigation | Detail |",
    "|----|--------|---------------|--------|",
]
if scenario_rows:
    for s in scenario_rows:
        lines.append(
            f"| {s.get('id','')} | {s.get('status','')} | {s.get('investigation_id','')} | {s.get('detail','')} |"
        )
else:
    lines.append("| — | not run | — | run `run-validation-scenarios.sh` |")

lines += [
    "",
    "## Langfuse quality (manual)",
    "",
    "- [ ] S1 consultant trace reviewed",
    "- [ ] S2 intel trace reviewed",
    "- [ ] S3 soc sparse trace reviewed",
    "",
    "## Deferred / warnings",
    "",
]
if phase8_deferred:
    lines.append("- Phase 8 vLLM usage shaping — **deferred** (no code changes in this cycle).")
for w in warnings:
    lines.append(f"- Recommended SLO not met: {w}")

lines += [
    "",
    "## Sign-off",
    "",
    f"- Validation run: {now}",
    f"- Verdict: {verdict}",
    "- Phases deferred: Phase 8",
    "- Approved by: _pending_",
    "",
]

report = "\n".join(lines) + "\n"
out_path = os.environ.get("REPORT_PATH", "")
if out_path:
    Path(out_path).write_text(report)
print(report, end="")
PY
