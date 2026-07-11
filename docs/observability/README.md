# k3s observability runbooks

Index for offline k3s (P30) observability, validation gates, and worker telemetry.

## Quick commands

| Target | Command |
|--------|---------|
| Full baseline snapshot | `make k3s-baseline` |
| Critical queries only | `make k3s-baseline-critical` |
| Cluster snapshot | `make k3s-cluster-snapshot` |
| Phase 9 validation (full) | `make k3s-validation-gate` |
| Phase 9 infra only | `make k3s-validation-infra` |

Scripts live under [`scripts/k8s/`](../../scripts/k8s/README.md).

## Phase map

| Phase | Doc | Focus |
|-------|-----|-------|
| 0 | [k3s-bottleneck-baseline.md](k3s-bottleneck-baseline.md) | Initial Prometheus baseline |
| 0 | [k3s-bottleneck-slo.md](k3s-bottleneck-slo.md) | SLO definitions |
| 0 | [k3s-bottleneck-promql.yml](k3s-bottleneck-promql.yml) | PromQL query pack |
| 1 | [egregore-worker-metrics-adr.md](egregore-worker-metrics-adr.md) | Worker `:8081/metrics` ADR |
| 2 | [worker-latency-profile.md](worker-latency-profile.md) | Persona latency buckets |
| 3 | [worker-failure-taxonomy.md](worker-failure-taxonomy.md) | `cys_worker_job_failures_total` |
| 4 | [k3s-capacity-budget.md](k3s-capacity-budget.md) | CPU/memory quotas |
| 5 | [k3s-obs-access.md](k3s-obs-access.md) | Grafana/Prometheus URLs via TLS gateway |
| 6 | [gpu-host-ssot.md](gpu-host-ssot.md) | vLLM + GPU exporter SSOT |
| 7 | [veil-workers-offline-profile.md](veil-workers-offline-profile.md) | Veil worker scrape profiles |
| 7 | [veil-mcp-contract-matrix.md](veil-mcp-contract-matrix.md) | veil-mcp tool contract |
| 7 | [veil-mcp-failure-analysis.md](veil-mcp-failure-analysis.md) | veil-mcp failure modes |
| 8 | [k3s-rollout-pending-diagnosis.md](k3s-rollout-pending-diagnosis.md) | Pending pod triage |
| 8 | [k3s-cluster-snapshot.md](k3s-cluster-snapshot.md) | Cluster state capture |
| 9 | [k3s-validation-matrix.md](k3s-validation-matrix.md) | Validation gate matrix |
| 9 | [k3s-validation-scenarios.md](k3s-validation-scenarios.md) | Scenario catalog |

## Related deploy docs

- [k3s-offline-baseline.md](../deploy/k3s-offline-baseline.md) — offline lab stack
- [k3s-offline-observability-optional.md](../deploy/k3s-offline-observability-optional.md) — optional obs overlays
- [deploy/ports.md](../../deploy/ports.md) — NodePort SSOT
- [deploy/k8s/defectdojo-offline/README.md](../../deploy/k8s/defectdojo-offline/README.md) — ASPM in-cluster
- [deploy/k8s/veil-offline/README.md](../../deploy/k8s/veil-offline/README.md) — Veil offline profiles
- [deploy/gitlab/CI.md](../../deploy/gitlab/CI.md) — CI smoke + DefectDojo upload

## Examples

- [examples/baseline.example.json](examples/baseline.example.json) — redacted baseline JSON shape
