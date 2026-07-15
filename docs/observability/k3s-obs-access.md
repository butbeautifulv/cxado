# K3s observability access (offline P30)

SSOT env: [scripts/k8s/cxado-offline-env.sh](../../scripts/k8s/cxado-offline-env.sh) and optional [deploy/.secrets/cxado-k3s.env](../../deploy/.secrets/cxado-k3s.env) (gitignored).

Default node: `CXADO_NODE_IP=192.168.0.133` (USB WiFi). Corp NAT: `10.8.185.15` (TLS SAN).

## Service matrix

| Service | URL | Auth | Notes |
|---------|-----|------|-------|
| Prometheus | `https://${CXADO_NODE_IP}:30091` | TLS gateway (no basic auth) | API: `/api/v1/query`, UI: `/graph` |
| Grafana | `https://${CXADO_NODE_IP}:30002` | `admin` + secret `grafana-auth` | Dashboards below |
| Langfuse | `https://${CXADO_NODE_IP}:30001` | API keys in egregore secrets | Project `egregore-dev`; session = `engagement_id` |
| Egregore UI | `https://${CXADO_NODE_IP}:30300` or `:30301` | Per deployment | Operator console (Next.js) |
| Egregore API | `https://${CXADO_NODE_IP}:30300/v1/` | Per `AUTH_ENABLED` | Same-origin on :30300; direct: `/health` |
| Egregore metrics (gateway) | `https://${CXADO_NODE_IP}:30880/metrics` | None via gateway | Scraped in-cluster as `egregore-api:8080` |

Port matrix: [deploy/ports.md](../../deploy/ports.md)

## Grafana dashboards

| Dashboard | UID | Path |
|-----------|-----|------|
| cxado-overview | `cxado-overview` | `/d/cxado-overview` |
| egregore-cys-agi | `egregore-cys-agi` | `/d/egregore-cys-agi` |
| veil-graph | `veil-graph` | `/d/veil-graph` |

## Grafana admin password (do not commit)

```bash
source scripts/k8s/cxado-offline-env.sh
ssh -p "${CXADO_OFFLINE_SSH_PORT}" "${CXADO_OFFLINE_SSH_HOST}" \
  "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl -n cxado-obs get secret grafana-auth -o jsonpath='{.data.admin_password}' | base64 -d; echo"
```

## kubectl via SSH

```bash
source scripts/k8s/cxado-offline-env.sh
ssh -p "${CXADO_OFFLINE_SSH_PORT}" "${CXADO_OFFLINE_SSH_HOST}" \
  "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl get pods -n cxado-app"
```

`K3S_CONFIG_FILE=/dev/null` avoids permission noise from `/etc/rancher/k3s/config.yaml`.

## Baseline collection

```bash
make k3s-baseline-critical   # Prometheus only, critical query groups
make k3s-baseline            # Full catalog (27 queries)
make k3s-cluster-snapshot    # kubectl pod dump via SSH
```

Output: `deploy/.local/logs/k3s-baseline/` (gitignored).

## Langfuse drill-down (Phase 2)

1. Open `https://${CXADO_NODE_IP}:30001`
2. Project: `egregore-dev`
3. Filter traces: tool name `ti_search_in_category`, status error
4. Export one failed trace (redacted) to `deploy/.local/logs/k3s-baseline/langfuse-failure-example.json` — **do not commit** raw production traces

Correlation fields: `engagement_id`, `persona`, `correlation_id`, tool arguments as sent to veil-mcp.

## Prometheus quick checks

```bash
export CXADO_NODE_IP=192.168.0.133
curl -sk "https://${CXADO_NODE_IP}:30091/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
curl -sk -G "https://${CXADO_NODE_IP}:30091/api/v1/query" \
  --data-urlencode 'query=up{job=~"egregore.*|veil-mcp|vllm"}'
```

## Health smoke

```bash
./scripts/k8s/smoke-test.sh
./scripts/k8s/smoke-test-egregore-obs.sh
./scripts/k8s/smoke-test-veil-obs.sh
```
