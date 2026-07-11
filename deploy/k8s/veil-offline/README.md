# Veil offline k3s profiles

Helm values and Prometheus scrape are split by **profile** so graph-only deploys do not show false-red worker targets.

## Profiles

| Profile | Values | Workers | Prometheus worker jobs | Use case |
|---------|--------|---------|----------------------|----------|
| `graph-only` (default) | `values-graph-only.yaml` | replicas=0 | **off** | egregore MCP read (`ti_search_in_category`) |
| `workers-obs` | `+ values-workers-obs.yaml` | replicas=1 each | **on** | obs E2E, ingest/engage smoke |
| `full-loop` (future) | TBD | on + engage plane | on | veneno on k3s |

## Deploy

```bash
# Default — graph read plane only (P30 cxado offline)
VEIL_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-deploy-veil-offline.sh

# Optional workers + scrape overlay
VEIL_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-deploy-veil-offline.sh --with-workers-obs
```

`--with-workers-obs` sets `CXADO_VEIL_PROFILE=workers-obs` and refreshes Prometheus configmaps.

## Prometheus

```bash
# graph-only (default)
CXADO_VEIL_PROFILE=graph-only ./scripts/k8s/obs-create-configmaps.sh
kubectl -n cxado-obs rollout restart deploy/prometheus

# workers enabled
CXADO_VEIL_PROFILE=workers-obs ./scripts/k8s/obs-create-configmaps.sh
kubectl -n cxado-obs rollout restart deploy/prometheus
```

External label: `veil_profile=graph-only|workers-obs`.

## Audit / smoke

```bash
./scripts/k8s/audit-veil-workers.sh
./scripts/k8s/smoke-test-veil-obs.sh
CXADO_VEIL_PROFILE=workers-obs ./scripts/k8s/smoke-test-veil-obs.sh  # worker gates
```

## P30 verdict (Phase 6)

**Recommended:** `graph-only` + gated scrape (Path C). Workers are **not** required for egregore MCP read against static Neo4j graph pack.

Enable `workers-obs` only for: live TI ingest QA, veneno engage bridge on k3s, explicit obs E2E — after Phase 5 capacity review.
