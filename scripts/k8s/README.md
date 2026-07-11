# k3s scripts catalog

Shell helpers for offline k3s (P30), observability, validation, and CI deploy.

See also [docs/observability/README.md](../../docs/observability/README.md).

## Offline deploy

| Script | Purpose |
|--------|---------|
| `cxado-offline-env.sh` | Export env for P30 offline deploy |
| `k3s-deploy-cxado-offline.sh` | Egregore Helm stack |
| `k3s-deploy-veil-offline.sh` | Veil offline (`--with-workers-obs` optional) |
| `k3s-deploy-defectdojo.sh` | DefectDojo in-cluster + TLS gateway `:30808` |
| `k3s-deploy-langfuse-offline.sh` | Langfuse offline |
| `k3s-deploy-arch-docs-offline.sh` | Architecture docs site `:30080` |
| `offline-tls-apply.sh` | TLS gateway NodePorts |
| `egregore-helm-upgrade.sh` | Helm upgrade wrapper |

## Observability

| Script | Purpose |
|--------|---------|
| `obs-create-configmaps.sh` | Prometheus/Grafana configmaps (veil profile aware) |
| `collect-k3s-baseline.sh` | `make k3s-baseline` backend |
| `collect-k3s-cluster-snapshot.sh` | `make k3s-cluster-snapshot` backend |
| `generate-k3s-after-report.sh` | Baseline before/after markdown report |
| `smoke-test-egregore-obs.sh` | Egregore worker metrics smoke |
| `smoke-test-veil-obs.sh` | Veil obs smoke |
| `smoke-gpu-telemetry.sh` | GPU host exporter smoke |
| `diagnose-gpu-telemetry.sh` | GPU scrape triage |
| `audit-veil-workers.sh` | Veil worker profile audit |

## Validation gate (Phase 9)

| Script | Purpose |
|--------|---------|
| `run-k3s-validation-gate.sh` | Full validation (`make k3s-validation-gate`) |
| `run-validation-scenarios.sh` | Scenario runner |
| `diagnose-pending-pods.sh` | Pending pod diagnosis |

## Rollout verify

| Script | Purpose |
|--------|---------|
| `verify-egregore-rollout.sh` | Post-deploy egregore API check |
| `verify-egregore-ui-rollout.sh` | Post-deploy UI check |
| `smoke-egregore-ui-from-node.sh` | UI smoke from k3s node |
| `e2e-verify-egregore.sh` | E2E verification |

## DefectDojo migration

| Script | Purpose |
|--------|---------|
| `defectdojo-vm01-export-users.sh` | Export users from legacy VM |
| `defectdojo-vm01-decommission.sh` | VM_01 decommission helper |

## Bundles (airgap)

| Script | Purpose |
|--------|---------|
| `k3s-offline-bundle-egregore.sh` | Egregore image bundle |
| `k3s-offline-bundle-egregore-ui.sh` | Egregore UI image bundle |
| `k3s-offline-bundle-obs.sh` | Observability image bundle |
| `k3s-offline-bundle-min.sh` | Minimal bundle |
