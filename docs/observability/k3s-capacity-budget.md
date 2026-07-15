# k3s Capacity Budget — cxado-app (3-node offline)

**Phase:** 5 (P5.2) — updated for 3-node cluster  
**Control-plane:** P30 ~ 8 CPU / 14 GiB RAM  
**Workers:** 2 additional nodes (corp network)  
**Node allocatable (P30):** ~7200m CPU, ~12 GiB memory (kubelet reserved)

## Namespace quota (`cxado-app-cap`)

| Resource | Hard limit |
|----------|------------|
| `pods` | 35 |
| `requests.cpu` | 6000m |
| `requests.memory` | 12 Gi |
| `limits.cpu` | 16000m |
| `limits.memory` | 20 Gi |

## Egregore steady-state requests (offline values, 3-node)

| Workload | Replicas | req CPU | req RAM | Σ CPU |
|----------|----------|---------|---------|-------|
| egregore-api | 4 | 150m | 512Mi | 600m |
| egregore-worker | 8 | 200m | 640Mi | 1600m |
| egregore-ui | 2 | 50m | 128Mi | 100m |
| **egregore Σ** | | | | **2300m** |

## HPA (worker fixed at 8)

| Workload | Replicas | req CPU | Σ CPU |
|----------|----------|---------|-------|
| egregore-worker | 8 | 200m | 1600m |
| **egregore Σ** | | | **2300m** |

## Rollout worst case (worker strategy)

Worker offline profile: `maxSurge: 0`, `maxUnavailable: 1` → at most **9** worker pods during rollout (one extra during replace).

API: `maxSurge: 1` → transient +150m for one new api pod before old terminates.

## Neighbor workloads (estimate)

| Workload | req CPU (est.) |
|----------|----------------|
| siem-mcp | ~200m |
| tenable-mcp | ~200m |
| **MCP Σ** | ~400m |

## Budget check

| Scenario | CPU requests | vs quota 6000m |
|----------|--------------|----------------|
| Steady (8 workers) | ~2700m | OK |
| Rollout overlap | ~2850m | OK |

Pods spread across 3 nodes (no control-plane nodeSelector). App images via Nexus; infra via `k3s-offline-bundle-infra.sh`.

## Tuning knobs

| Knob | File | 3-node value |
|------|------|--------------|
| `api.replicas` | `values-egregore-offline.yaml` | 4 |
| `worker.replicas` | same | 8 |
| `worker.hpa.maxReplicas` | same | 8 |
| `ui.replicas` | same | 2 |
| `resources.worker.requests.cpu` | same | 200m |
| `rollout.worker.maxSurge` | same | 0 |
| Quota | `cxado-app-quota.yaml` | raised for 3-node |

## When to revisit

- Node added/removed → re-run `diagnose-pending-pods.sh` and update this table
- New MCP sidecars in `cxado-app` → re-run capacity check
