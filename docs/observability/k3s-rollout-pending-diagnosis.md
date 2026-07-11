# k3s Rollout Pending — Root Cause Diagnosis

**Phase:** 5 (P5.1)  
**Cluster:** P30 offline (`bbv-p30-k44`, single control-plane node)  
**Namespace:** `cxado-app`

## Summary

Baseline rollout failures (2026-07-09 probe) were caused by **scheduler CPU request pressure** during overlapping ReplicaSets, not by real CPU starvation on the host. The scheduler accounts for **sum of container requests**, namespace **ResourceQuota**, and **rollout surge** — default `maxSurge: 25%` on worker replicas=4 created transient unschedulable pods.

Current state (post Phase 5 fixes): **0 Pending** api/worker pods; HPA capped at 3 workers; worker rollout uses `maxSurge: 0`.

## Baseline pending pods (historical)

| Pod | Scheduler event (typical) | Category | Fix track |
|-----|---------------------------|----------|-----------|
| `egregore-worker-579666895d-48sks` | `0/1 nodes available: 1 Insufficient cpu` | `quota_cpu` + `stale_rollout` | P5.2 replicas/requests, P5.3 surge |
| `egregore-api-667dcb4f6b-zwfht` | `0/1 nodes available: 1 Insufficient cpu` | `quota_cpu` + `stale_rollout` | P5.2 + P5.3 |

Evidence pattern (not verbatim — pods deleted after rollback):

- Global node CPU utilization low (`kubectl top`) while new RS pods stay **Pending**
- Overlap: old RS (2 Running workers) + new RS surge (+1 api, +1 worker) + `worker.replicas: 4` in values
- Namespace quota `requests.cpu: 3750m` not fully exhausted, but **node allocatable scheduling** with control-plane taints and neighbor MCP pods left insufficient **request headroom** for surge pods

## Classification enum

| Category | Meaning |
|----------|---------|
| `quota_cpu` | `ResourceQuota` `requests.cpu` exceeded |
| `quota_memory` | `requests.memory` exceeded |
| `quota_pods` | pod count quota |
| `node_cpu` | Insufficient cpu on schedulable nodes |
| `node_memory` | Insufficient memory |
| `node_selector` | No node matches selector |
| `taint` | Toleration missing |
| `image_pull` | ImagePullBackOff (not Pending long-term) |
| `pvc` | Volume bind failure |
| `host_path` | hostPath mount failure |
| `stale_rollout` | Dead RS + surge overlap |
| `unknown` | Unclassified |

## Related issues (out of scope api/worker Pending)

| Symptom | Category | Notes |
|---------|----------|-------|
| `egregore-ui` ImagePullBackOff | `image_pull` | Next.js UI not bundled in default offline path — use `ui.replicas: 0` + ui-minimal, or bundle UI first |

## Diagnosis workflow

```bash
./scripts/k8s/diagnose-pending-pods.sh
```

Logs: `deploy_logs/k3s-baseline/pending-diagnosis-*.log`

## Fixes applied (Phase 5)

1. **Capacity:** worker steady replicas 2, HPA max 3, requests.cpu 200m — see [k3s-capacity-budget.md](k3s-capacity-budget.md)
2. **Rollout:** worker `maxSurge: 0`, `maxUnavailable: 1`; api `maxSurge: 1`, `maxUnavailable: 0`
3. **HPA drift:** `worker-hpa.yaml` template in Helm chart (was missing from git, present on cluster)
4. **Gate:** `verify-egregore-rollout.sh` after every helm upgrade
5. **Alert:** `EgregorePodsPending` in `egregore-alerts.yml`

## Re-test checklist

After `helm upgrade`:

```bash
./scripts/k8s/verify-egregore-rollout.sh
```

PromQL: `kube_pod_status_phase{namespace="cxado-app",phase="Pending",pod=~"egregore-.*"} == 0`
