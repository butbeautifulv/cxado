# K3s validation matrix (Phase 9)

Cross-phase SLO rollup for [`run-k3s-validation-gate.sh`](../../scripts/k8s/run-k3s-validation-gate.sh).

**Baseline snapshot (before):** Phase 0 `deploy/.local/logs/k3s-baseline/baseline-*.json` (gitignored)  
**After snapshot:** collected at end of validation run  
**Report:** [k3s-bottleneck-after-report.md](k3s-bottleneck-after-report.md)

## Tier policy

| Tier | Phases | Blocks gate exit? |
|------|--------|-------------------|
| **Blocking** | 1, 2, 3, 5, 6 | Yes |
| **Recommended** | 4, 7 | Warning → CONDITIONAL verdict |
| **Deferred** | 8 | Skipped when not deployed |
| **Informational** | Langfuse quality checklist | No auto-fail |

## Matrix

| Phase | SLO | PromQL / check | Query id | Baseline (2026-07-09) | Target (pass) | Actual (fill on run) |
|-------|-----|----------------|----------|----------------------|---------------|----------------------|
| 0 | Repeatable snapshot | `collect-k3s-baseline.sh` | — | `baseline-*.json` exists | after snapshot comparable | |
| 1 | Worker scrape | `up{job="egregore-worker"}==1` | `egregore_worker_scrape_up` | absent | all Running workers | |
| 2 | ti_search | `increase(cys_tool_invocations_total{tool="ti_search_in_category",result="success"}[1h])>0` | `ti_search_success_7d` | 72 err / 0 ok (7d) | success > 0 in window | |
| 3 | Failure reasons | `topk(5, sum(increase(cys_worker_job_failures_total[7d])) by (reason))` | `worker_failures_by_reason_7d` | only `status=error` | non-empty `reason` labels | |
| 4 | soc p95 | `histogram_quantile(0.95, sum(rate(cys_worker_job_duration_seconds_bucket{persona="soc"}[7d])) by (le))` | `worker_p95_7d` | 600s ceiling | < 600s (stretch < 480s) | |
| 5 | Pending pods | `kube_pod_status_phase{namespace="cxado-app",phase="Pending",pod=~"egregore-.*"}==0` | `pending_egregore` | 2 pending | 0 | |
| 6 | Veil workers | graph-only: no worker scrape targets down | `veil_worker_scrape_count` | 3 down | 0 targets or workers up | |
| 7 | GPU telemetry | `up{job="proxmox-gpu-dcgm"}==1` | `gpu_dcgm_up` | down | up | |
| 8 | vLLM shaping | B2 tokens / vLLM p95 | `tokens_7d`, `vllm_e2e_p95_1h` | — | **DEFERRED** (Phase 8 skipped) | |
| 9 | Validation report | `generate-k3s-after-report.sh` | — | — | PASS or CONDITIONAL | |

## Infra gates (P9.2)

| Step | Script | Pass |
|------|--------|------|
| I1 | `smoke-test-egregore-obs.sh` | api + worker obs |
| I2 | `verify-egregore-rollout.sh` | 0 pending, READY==DESIRED |
| I3 | `smoke-test-veil-obs.sh` | veil-api/mcp + profile scrape |
| I4 | Prometheus | `min(up{job=~"egregore-api\|veil-mcp\|vllm"}==1)` and `count(up{job="egregore-worker"}==1)>=1` |
| I5 | `smoke-gpu-telemetry.sh` | recommended (warning only) |

## Scenarios (P9.3)

See [k3s-validation-scenarios.md](k3s-validation-scenarios.md).

## Verdict rules

- **PASS:** all blocking rows pass; recommended rows pass or documented waiver
- **CONDITIONAL:** blocking pass; one or more recommended/deferred rows fail with documented reason
- **FAIL:** any blocking row fails, or scenario S2 (ti_search) fails
