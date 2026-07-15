# K3s bottleneck SLO and acceptance criteria

SSOT PromQL catalog: [k3s-bottleneck-promql.yml](k3s-bottleneck-promql.yml)

Baseline snapshot (human report): [k3s-bottleneck-baseline.md](k3s-bottleneck-baseline.md)

Cluster state: [k3s-cluster-snapshot.md](k3s-cluster-snapshot.md)

Access runbook: [k3s-obs-access.md](k3s-obs-access.md)

## How to refresh baseline

```bash
make k3s-baseline-critical   # fast subset
make k3s-baseline            # full catalog
make k3s-cluster-snapshot    # kubectl state via SSH
```

Snapshots are written under `deploy/.local/logs/k3s-baseline/` (gitignored). Commit only redacted examples under `docs/observability/examples/`.

## Phase SLO table

| Phase | SLO | Baseline (2026-07-09, P30) | Query id(s) |
|-------|-----|---------------------------|-------------|
| 0 Baseline | Repeatable snapshot + docs | This document | `scrape_up`, `worker_p95_7d` |
| 1 Worker obs | `up{job="egregore-worker"} == 1` per Running pod **or** documented multiproc path with acceptance test | Worker scrape **absent**; metrics via API only | `egregore_worker_scrape_up` |
| 2 Veil MCP | `ti_search_in_category` success > 0 on smoke; 0 errors in smoke window | **72 err / 0 ok** (7d) | `ti_search_errors_7d`, `ti_search_success_7d` |
| 3 Taxonomy | `cys_worker_job_failures_total{reason=...}` non-empty distribution | Only `status=error` on duration histogram | `worker_error_ratio_7d` |
| 4 Latency | `soc` p95 < 600s on fixed smoke workload | `soc` p95 = **600s** (ceiling) | `worker_p95_7d` |
| 5 Rollout | Pending `egregore-*` = 0 after rollout | **2 pending** pods | `pending_egregore` |
| 6 Veil workers | No false-red targets for enabled profile | 3 veil background workers **down** | `scrape_down` |
| 7 GPU telemetry | `up{job="proxmox-gpu-dcgm"} == 1` | **down** | `scrape_down` |
| 8 vLLM shaping | Token rate ↓ or vLLM p95 ↓ without error regression | vLLM avg ~63s, p95 ~182s | `vllm_e2e_p95_1h`, `tokens_7d` |
| 9 Validation | Before/after report PASS on blocking SLOs | — | all critical groups |

## Critical query groups

The collector treats these YAML groups as **blocking** (exit 1 if Prometheus unreachable or query parse fails):

- `scrape_health`
- `worker_jobs`
- `tools`
- `llm`
- `k8s` (`pending_egregore` only when `BASELINE_CRITICAL_ONLY=1` uses subset)

Empty result vectors (e.g. no `egregore-worker` job) are **valid** and document observability gaps.

## Per-phase acceptance (detail)

### Phase 1 — Worker observability

- **Pass:** `count(up{job="egregore-worker"} == 1) == count(kube_pod_status_phase{namespace="cxado-app",pod=~"egregore-worker-.*",phase="Running"})`
- **Fallback:** ADR documents Strategy B (shared hostPath multiproc) with explicit smoke test

### Phase 2 — Veil MCP

- **Pass:** `ti_search_success_7d > 0` after smoke; `ti_search_errors_7d` not increasing in validation window
- **Control:** `veil_mcp_p95_7d` remains low (Veil is not the latency bottleneck)

### Phase 3 — Failure taxonomy

- **Pass:** Top failure reasons visible: `topk(5, sum(increase(cys_worker_job_failures_total[7d])) by (reason))`

### Phase 4 — Latency

- **Pass:** `worker_p95_7d{persona="soc"} < 600`
- **Stretch:** `soc` p95 < 480s on same fixture

### Phase 5 — Rollout health

- **Pass:** `pending_egregore` empty; `egregore_restarts_24h` stable during validation window

### Phase 6 — Veil workers profile

- **Path C (default):** Scrape jobs for disabled workers removed or relabeled `profile=graph-only`
- **Path B:** Workers Running and `up{job=~"veil-.*-worker"} == 1`

### Phase 7 — GPU telemetry

- **Pass:** `up{job="proxmox-gpu-node"} == 1` and `up{job="proxmox-gpu-dcgm"} == 1`
- Correlate with `vllm_e2e_p95_1h` in reports

### Phase 8 — vLLM usage shaping

- **Pass:** B2 benchmark shows ↓ tokens or ↓ p95 vs Phase 0 baseline; worker error ratio not worse

### Phase 9 — Validation gate

- **Pass:** [k3s-bottleneck-after-report.md](k3s-bottleneck-after-report.md) verdict PASS or CONDITIONAL with documented deferrals
- **Matrix:** [k3s-validation-matrix.md](k3s-validation-matrix.md)
- **Run:** `make k3s-validation-infra` (fast) or `make k3s-validation-gate` (full)

## Known baseline gaps (2026-07-09)

Documented in baseline report; do not treat as Phase 0 failures:

| Gap | Impact |
|-----|--------|
| No `egregore-worker` scrape | Worker metrics incomplete / stale |
| `ti_search_in_category` 100% errors | Intel persona blocked |
| GPU exporters down | Cannot correlate vLLM with GPU util |
| Veil background workers down | False-red targets in graph-only profile |
| 2 pending egregore pods | Rollout stuck on capacity |

**Update (Phase 7 complete):** GPU telemetry restored on `phy-gpu-host01`; see after-report.

## Dashboards (Grafana)

| Dashboard | UID (offline) | Use |
|-----------|---------------|-----|
| cxado-overview | `cxado-overview` | Platform health |
| egregore-cys-agi | `egregore-cys-agi` | Worker jobs, tools, tokens |
| veil-graph | `veil-graph` | Veil HTTP latency |

See [k3s-obs-access.md](k3s-obs-access.md) for URLs and auth.
