# ADR: Egregore worker Prometheus metrics (Strategy A)

**Status:** Accepted  
**Date:** 2026-07-09  
**Phase:** 1 — Worker observability  
**Baseline:** [k3s-bottleneck-baseline.md](k3s-bottleneck-baseline.md)

## Context

Worker jobs emit Prometheus metrics (`cys_worker_job_duration_seconds_*`, `cys_tool_invocations_total`, `cys_job_tokens_total`) via `prometheus_client` multiprocess mode (`PROMETHEUS_MULTIPROC_DIR`).

On k3s offline today:

- Prometheus scrapes **only** `egregore-api:8080/metrics` ([prometheus-k3s.yml](../../deploy/k8s/obs-offline/prometheus-k3s.yml)).
- Worker pods use **per-pod `emptyDir`** for `/tmp/prom-multiproc` (`multiprocHostPath: ""` in [values-egregore-offline.yaml](../../deploy/k8s/cxado-offline/values-egregore-offline.yaml)).
- Worker Helm template had **no HTTP metrics port** ([worker-deployment.yaml](../../projects/egregore/deploy/helm/egregore/templates/worker-deployment.yaml)).

Local dev shares one multiproc directory across API + workers ([dev.sh](../../projects/egregore/scripts/dev.sh)), so metrics appear complete when scraping API only.

## Evidence (P30, 2026-07-09)

| Check | Result |
|-------|--------|
| `up{job="egregore-worker"}` | **Empty** — no scrape job |
| `up{job="egregore-api"}` | 1 |
| Worker series in Prometheus | Present via API scrape (incomplete / stale risk) |
| `ti_search_in_category` errors | 72 / 0 success (7d) — unrelated but blocks trusting worker SLOs |
| Pending egregore pods at baseline | 0 at snapshot (historical 2 pending during rollout) |

## Decision

**Strategy A — per-pod `/metrics` HTTP + kubernetes_sd scrape**

Each `egregore-worker` pod:

1. Runs background metrics HTTP on port **8081** (`EGREGORE_METRICS_PORT`, `--metrics-port`).
2. Exposes `GET /metrics` and `GET /health`.
3. Uses pod annotations `prometheus.io/scrape=true`, `prometheus.io/port=8081`.

Prometheus:

1. ServiceAccount `prometheus` in `cxado-obs` with Role to list/watch pods in `cxado-app`.
2. `job_name: egregore-worker` via `kubernetes_sd_configs` (pod role).

## Rejected alternatives

| Strategy | Verdict | Reason |
|----------|---------|--------|
| B — shared hostPath multiproc + API scrape only | Fallback only | Breaks on multi-node; ghost `.db` files; documented in § Fallback |
| C — ClusterIP Service round-robin scrape | Reject | Incomplete series per scrape |

## Label contract

| Label | API job | Worker job |
|-------|---------|------------|
| `job` | `egregore-api` | `egregore-worker` |
| `platform` | `egregore` | `egregore` |
| `component` | `ingress` | `worker` |
| `pod` | — | from kubernetes_sd |
| `namespace` | — | `cxado-app` |

Grafana worker panels filter `job="egregore-worker"`. API-only gauges (`cys_hitl_pending_total`, `cys_investigations_active`, `cys_events_ingested_total`) use `job="egregore-api"`.

## Implementation

| Layer | Change |
|-------|--------|
| Python | `cys_core.observability.http.start_metrics_server`, `ensure_worker_metrics_server` |
| CLI | `egregore worker --daemon --metrics-port 8081` |
| Helm | metrics port, probes, annotations |
| Prometheus | RBAC + `egregore-worker` scrape job |
| Alerts | `EgregoreWorkerScrapeDown`, ratio-based `EgregoreWorkerJobErrors` |

## Rollback

1. Remove `egregore-worker` job from `prometheus-k3s.yml` and reload Prometheus.
2. Remove `EGREGORE_METRICS_PORT` / `--metrics-port` from worker deployment.
3. Revert Grafana queries to unfiltered (pre-Phase-1) if needed.

## Fallback: Strategy B (hostPath multiproc)

Enable **only** when kubernetes_sd is blocked and **all** workers + API run on a single node:

```yaml
prometheus:
  multiprocHostPath: /var/lib/cxado/prom-multiproc
```

Risks: ghost metrics after crash, manual `sudo rm /var/lib/cxado/prom-multiproc/*.db`, no per-pod attribution.

**Do not combine Strategy A scrape with Strategy B hostPath.**

## Verification

```promql
up{job="egregore-worker"}
count(up{job="egregore-worker"} == 1) == count(kube_pod_status_phase{namespace="cxado-app",pod=~"egregore-worker-.*",phase="Running"})
```

```bash
./scripts/k8s/smoke-test-egregore-obs.sh
```
