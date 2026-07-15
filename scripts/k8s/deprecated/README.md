# Deprecated k8s scripts (tar import fallback)

Superseded by Nexus Kaniko loops — see [docs/deploy/nexus-egregore-loop.md](../../docs/deploy/nexus-egregore-loop.md).

| Script | Replacement |
|--------|-------------|
| `k3s-offline-bundle-obs.sh` | `obs-create-configmaps.sh` + manifest apply in `k3s-deploy-cxado-offline.sh` |
| `k3s-offline-bundle-langfuse.sh` | `k3s-deploy-langfuse-offline.sh` |
| `k3s-offline-bundle-redpanda.sh` | redpanda in `deploy/k8s/cxado-offline/14-redpanda.yaml` + infra tar |

Active infra import: [`../k3s-offline-bundle-infra.sh`](../k3s-offline-bundle-infra.sh).
