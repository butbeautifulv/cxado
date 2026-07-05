# K3s deploy backlog (deferred until cluster available)

Execute as **one sprint** when `kubectl` / offline SSH is reachable.

## Queue and catalog

| Todo | Command / artifact |
|------|-------------------|
| que-07 | `CXADO_OFFLINE_TAG=offline-YYYYMMDD-queue ./scripts/k8s/egregore-helm-upgrade.sh` |
| que-08 | LAG gate: `rpk group describe egregore-workers` → LAG=0 under parallel POST |
| cat-07 | Helm init job → `catalog_seed_bootstrap.sh` |
| dep-kafka-max-poll | Image tag `offline-YYYYMMDD-kafkapoll` |

## Stream A gates

| Phase | Script |
|-------|--------|
| P4 E2E | `scripts/k8s/e2e-verify-egregore.sh` |
| P5 benchmarks | `scripts/k8s/langfuse-benchmark-report.sh` |
| P7 UI | AD investigation UI gate |
| P8 obs | kubectl callback / veil-mcp / Tempo gates |
| P9 Kafka | Fresh AD ≤180s, consultant LAG=0 |

## Artifacts

- `deploy_logs/e2e_verify_*.log`
- `deploy_logs/kafka_lag_*.md`
- `deploy_logs/trace_audit_*.md`

## References

- [docs/deploy/cxado-default-stack.md](../docs/deploy/cxado-default-stack.md)
- [scripts/k8s/egregore-helm-upgrade.sh](../scripts/k8s/egregore-helm-upgrade.sh)
