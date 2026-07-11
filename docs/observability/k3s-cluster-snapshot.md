# K3s cluster snapshot (cxado offline)

Captured: **2026-07-09** via SSH to `bbv-p30-wifi` (`CXADO_NODE_IP=192.168.0.133`).

Collector: `./scripts/k8s/collect-k3s-cluster-snapshot.sh`

## Nodes

| Name | Role | Internal IP | Status |
|------|------|-------------|--------|
| bbv-p30-k44 | control-plane | 10.8.185.15 | Ready |
| svo-aosint-ps01 | worker | 10.20.16.195 | Ready |
| svo-pntmon-ps01 | worker | 10.20.16.185 | Ready |

## cxado-app (egregore + MCP sidecars)

| Pod | Ready | Status | Restarts | Age | Notes |
|-----|-------|--------|----------|-----|-------|
| egregore-api-6bc76b59b6-dntzg | 1/1 | Running | 1 | ~45h | Active API |
| egregore-worker-fff8bfffd-4psd7 | 1/1 | Running | 1 | ~45h | Worker (no metrics port) |
| egregore-worker-fff8bfffd-fjcg7 | 1/1 | Running | 1 | ~45h | Worker (no metrics port) |
| egregore-ui-7b89fb8845-* | 2/2 | Running | 0 | ~66m | UI rollout |
| siem-mcp-85ffd7595f-fkkgl | 1/1 | Running | 2 | ~47h | |
| tenable-mcp-64b9558b4-rzpdb | 1/1 | Running | 1 | ~45h | |

**Pending egregore pods at snapshot:** none.

Earlier investigation (master plan probe) reported `egregore-worker-579666895d-48sks` and `egregore-api-667dcb4f6b-zwfht` Pending — likely superseded by current ReplicaSet `fff8bfffd` / `6bc76b59b6`. Re-check after next Helm upgrade (Phase 5).

## veil

| Pod | Ready | Status |
|-----|-------|--------|
| veil-veil-api-6f4d9b7d94-zsl2d | 1/1 | Running |
| veil-veil-mcp-7849f7dc45-bclnp | 1/1 | Running |
| neo4j-0 (veil-data) | 1/1 | Running |
| nats (veil-data) | 1/1 | Running |

Veil background workers (ingest/pipeline/engage-events) **not deployed** in graph-only profile — Prometheus targets for them are down by design until Phase 6.

## cxado-obs

| Pod | Ready | Status | Notes |
|-----|-------|--------|-------|
| prometheus-645bb9c7ff-tfgkj | 1/1 | Running | |
| grafana-6f5754b46b-96npb | 2/2 | Running | |
| tempo, loki | 1/1 | Running | |
| kube-state-metrics | 1/1 | Running | |
| node-exporter (control-plane) | 1/1 | Running | |
| node-exporter (worker nodes) | 0/1 | ImagePullBackOff | On `svo-aosint-ps01`, `svo-pntmon-ps01` |
| promtail (worker nodes) | 0/1 | ImagePullBackOff | Same worker nodes |

Worker-node ImagePullBackOff is a separate infra issue (image pull on corp workers); control-plane observability is healthy.

## Diagnostic commands

```bash
source scripts/k8s/cxado-offline-env.sh

ssh -p "${CXADO_OFFLINE_SSH_PORT}" "${CXADO_OFFLINE_SSH_HOST}" \
  "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl get nodes -o wide"

ssh -p "${CXADO_OFFLINE_SSH_PORT}" "${CXADO_OFFLINE_SSH_HOST}" \
  "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl get pods -A -o wide | grep -E 'cxado-app|veil|cxado-obs'"

# Pending egregore (expect empty after healthy rollout)
ssh -p "${CXADO_OFFLINE_SSH_PORT}" "${CXADO_OFFLINE_SSH_HOST}" \
  "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl get pods -n cxado-app --field-selector=status.phase=Pending"

# Scheduler events for a stuck pod
ssh -p "${CXADO_OFFLINE_SSH_PORT}" "${CXADO_OFFLINE_SSH_HOST}" \
  "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl describe pod -n cxado-app <pod-name> | tail -40"
```

## Resource pressure checks (Phase 5)

```bash
ssh ... "k3s kubectl top pods -n cxado-app 2>/dev/null || true"
ssh ... "k3s kubectl describe resourcequota -n cxado-app"
ssh ... "k3s kubectl get events -n cxado-app --sort-by='.lastTimestamp' | tail -20"
```
