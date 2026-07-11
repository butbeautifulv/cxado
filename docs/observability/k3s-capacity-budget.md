# k3s Capacity Budget — cxado-app (P30)

**Phase:** 5 (P5.2)  
**Host:** P30 ~ 8 CPU / 14 GiB RAM  
**Node allocatable:** ~7200m CPU, ~12 GiB memory (kubelet reserved)

## Namespace quota (`cxado-app-cap`)

| Resource | Hard limit |
|----------|------------|
| `pods` | 25 |
| `requests.cpu` | 3750m |
| `requests.memory` | 7 Gi |
| `limits.cpu` | 6000m |
| `limits.memory` | 9 Gi |

## Egregore steady-state requests (offline values, post Phase 5)

| Workload | Replicas | req CPU | req RAM | Σ CPU |
|----------|----------|---------|---------|-------|
| egregore-api | 1 | 150m | 512Mi | 150m |
| egregore-worker | 2 (HPA min) | 200m | 640Mi | 400m |
| egregore-ui | **0** (disabled) | — | — | 0m |
| **egregore Σ** | | | | **550m** |

## HPA worst case (worker maxReplicas=3)

| Workload | Replicas | req CPU | Σ CPU |
|----------|----------|---------|-------|
| egregore-worker | 3 | 200m | 600m |
| **egregore Σ (HPA max)** | | | **750m** |

## Rollout worst case (worker strategy)

Worker offline profile: `maxSurge: 0`, `maxUnavailable: 1` → at most **3** worker pods during rollout (no extra surge pod).

API: `maxSurge: 1` → transient +150m for one new api pod before old terminates.

```
worst_case_cpu_requests =
  egregore_steady_or_hpa_max
  + api_rollout_surge (150m)
  + mcp_neighbors
```

## Neighbor workloads (estimate)

| Workload | req CPU (est.) |
|----------|----------------|
| siem-mcp | ~200m |
| tenable-mcp | ~200m |
| **MCP Σ** | ~400m |

## Budget check

| Scenario | CPU requests | vs quota 3750m | vs node 7200m |
|----------|--------------|----------------|---------------|
| Steady (2 workers) | ~1050m | OK | OK |
| HPA max (3 workers) | ~1250m | OK | OK |
| Old config (4 workers + surge) | ~1850m+ overlap | Risk Pending | Risk Pending |

**Formula:**

```
must be < min(quota.requests.cpu, node.allocatable.cpu - system_reserved)
```

Phase 5 did **not** raise quota — reduced egregore footprint instead (Tier B + C).

## Tuning knobs

| Knob | File | P30 value |
|------|------|-----------|
| `worker.replicas` | `values-egregore-offline.yaml` | 2 |
| `worker.hpa.maxReplicas` | same | 3 |
| `resources.worker.requests.cpu` | same | 200m |
| `rollout.worker.maxSurge` | same | 0 |
| Quota | `cxado-app-quota.yaml` | unchanged |

## When to revisit

- Second k3s node added → may raise HPA max and worker surge
- New MCP sidecars in `cxado-app` → re-run `diagnose-pending-pods.sh` and update this table
