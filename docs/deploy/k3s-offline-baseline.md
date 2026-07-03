# k3s offline baseline (cxado)

This doc captures the minimal “do-not-break-offline” patterns discovered during offline deployments.

## `enableServiceLinks: false`

Why:
- Kubernetes injects Service-derived env vars into Pods by default (e.g. `NEO4J_PORT_7687_TCP_PORT`).
- Some apps (notably Neo4j) can misinterpret those variables as config keys and fail startup.

Where to apply:
- **All stateful / strict-config services** (at least Neo4j).
- Recommended as a **default** for cxado workloads unless a chart explicitly relies on service env injection.

Examples:
- Raw manifest: `spec.enableServiceLinks: false`
- Terraform provider (kubernetes_*): `spec { enable_service_links = false }`

## Offline pull policy

Rule:
- For offline clusters, **always** set `imagePullPolicy: IfNotPresent` (or chart equivalent).

Why:
- Prevents Kubernetes from trying to pull images from the internet/registry when they were already imported into containerd.

## k3s boot race (no default route)

Symptom:
- `k3s.service` fails on boot with: `no default routes found`.

Fix:
- Add a systemd drop-in that waits for `network-online.target` and for a default route to appear before starting k3s.

Reference (example used on `10.8.185.15`):
- `/etc/systemd/system/k3s.service.d/override.conf` with `After=Wants=network-online.target` and an `ExecStartPre` route check loop.

## Veil skills-index artifact (hostPath variant)

Current baseline (single-node, fastest):
- Veil chart mounts `hostPath` from the node:
  - node: `/var/lib/veil/playbooks/docs/skills-index`
  - container: `/home/nonroot/docs/skills-index`
- Bootstrap script:
  - `scripts/veil/bootstrap-skills-index-hostpath.sh /path/to/veil_skills_index.tgz`

Trade-offs:
- Pros: no PVC/storageclass required, trivial offline workflow.
- Cons: node-local state; for multi-node or scaling prefer PVC + initContainer.

## External vLLM (egregore LLM)

Egregore uses the **litellm** Python library (not a separate LiteLLM proxy server). Point workloads at an external OpenAI-compatible vLLM endpoint.

Helm values (`deploy/k8s/cxado-offline/values-egregore-offline.yaml`):

```yaml
llm:
  provider: litellm
  model: openai/<model-id-from-v1-models>
  baseUrl: http://10.8.185.186:11612/v1
  temperature: "0.1"
```

Discover model id:

```bash
curl -fsS http://10.8.185.186:11612/v1/models | jq .
```

Smoke from api pod (after helm upgrade):

```bash
kubectl -n cxado-app exec deploy/egregore-api -- env | grep LLM_
kubectl -n cxado-app exec deploy/egregore-api -- \
  curl -fsS "${LLM_BASE_URL}/models"
curl -fsS -X POST http://localhost:8080/sessions \
  -H 'Content-Type: application/json' \
  -d '{"goal":"smoke test","message":"hello","mode":"ask"}'
```

When `LLM_BASE_URL` is set, cloud API keys can stay empty — egregore passes a dummy key for local OpenAI-compatible servers.

### Prometheus monitoring (external vLLM + GPU host)

vLLM runs on the Proxmox GPU VM, not inside k3s. Prometheus on the k3s node (`10.8.185.15`) scrapes:

| Job | Target | What |
|-----|--------|------|
| `vllm` | `10.8.185.186:11612/metrics` | vLLM inference metrics (`vllm:*`) |
| `proxmox-gpu-node` | `10.8.185.186:9100` | Host CPU/RAM/disk (node-exporter on GPU VM) |
| `proxmox-gpu-dcgm` | `10.8.185.186:9400` | NVIDIA GPU util / VRAM (DCGM exporter) |

Config: `deploy/k8s/obs-offline/prometheus-k3s.yml`  
Grafana dashboard: `deploy/observability/grafana/dashboards/infra/vllm-monitoring.json`

On the GPU VM (`10.8.185.186`), install exporters (see `scripts/obs/proxmox-gpu-exporters.example.sh`):

```bash
# After network is up — verify from k3s node:
curl -fsS http://10.8.185.186:11612/metrics | head
curl -fsS http://10.8.185.186:9100/metrics | head
curl -fsS http://10.8.185.186:9400/metrics | head
```

Refresh Prometheus config on k3s:

```bash
./scripts/k8s/obs-create-configmaps.sh
kubectl -n cxado-obs rollout restart deployment/prometheus
```

## Architecture docs site (hostPath)

Static architecture landing for architects: `docs/architecture-site/` → nginx on k3s.

| Item | Value |
|------|-------|
| Node path | `/home/bbv/cxado/arch-docs` |
| k8s workload | `cxado-arch-docs` in `cxado-edge` |
| TLS URL | `https://<node>:30080` |

```bash
# On k3s node (or --remote via SSH forward):
./scripts/k8s/k3s-offline-bundle-arch-docs.sh
./scripts/k8s/k3s-deploy-arch-docs-offline.sh

# Smoke:
CXADO_ARCH_DOCS_HOST=10.8.185.15 CXADO_ARCH_DOCS_INSECURE=1 \
  ./scripts/k8s/smoke-test-arch-docs.sh
```

Manifests: `deploy/k8s/arch-docs-offline/` · gateway patch: `deploy/k8s/offline-tls/`.

## SSH / deploy hop (default)

Deploy scripts source `scripts/k8s/cxado-offline-env.sh`. Defaults target **direct WiFi** to P30:

| Variable | Default | Meaning |
|----------|---------|---------|
| `CXADO_OFFLINE_SSH_HOST` | `bbv-p30-wifi` | SSH alias (`~/.ssh/config` → `192.168.0.133:22`) |
| `CXADO_OFFLINE_SSH_PORT` | `22` | WiFi direct port |
| `CXADO_NODE_IP` | `192.168.0.133` | NodePort / HTTPS URLs on LAN |

Corp NAT hop (when laptop is not on P30 WiFi):

```bash
export CXADO_OFFLINE_SSH_HOST=bbv-p30-k44
export CXADO_OFFLINE_SSH_PORT=22012
export CXADO_NODE_IP=10.8.185.15
```

Optional overrides: copy `deploy/.secrets/cxado-k3s.env.example` → `deploy/.secrets/cxado-k3s.env`.

Grafana dashboards only:

```bash
./scripts/k8s/obs-deploy-dashboards.sh
```

