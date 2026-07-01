# cxado on Kubernetes (kind) — Terraform + Helm

> **Status:** experimental — `make cxado-k8s-up` works for health smoke; graph-bootstrap, migrate job, and Grafana dashboards may need manual steps (see Known gaps).

Local profile for the full cxado stack on **kind**, parallel to Docker Compose (`make cxado-up`).

## Prerequisites

- [kind](https://kind.sigs.k8s.io/), kubectl, helm, terraform, docker
- LLM keys in `projects/egregore/.env` (optional for health-only smoke)

## Quick start

```bash
# 1. kind cluster + ingress-nginx
make cxado-kind-up

# 2. Build and load app images into kind
make cxado-k8s-build-images

# 3. Terraform apply (data plane + veil + egregore + observability)
make cxado-tf-init
make cxado-tf-apply

# 4. Status + smoke
make cxado-k8s-status
make cxado-k8s-smoke
```

## Endpoints (kind port mappings)

| URL | Service |
|-----|---------|
| http://127.0.0.1:8080/health | egregore API |
| http://127.0.0.1:3000 | egregore UI |
| http://127.0.0.1:8090/health | veil-api |
| http://127.0.0.1:8091/health | veil-mcp |
| http://127.0.0.1:3002 | Grafana |
| http://127.0.0.1:9091 | Prometheus |

## Layout

```
deploy/k8s/kind/cxado-kind.yaml       # kind cluster config
deploy/terraform/cxado-kind/          # Terraform root (Helm releases)
projects/egregore/deploy/helm/egregore/
scripts/k8s/                        # bootstrap, build, smoke
```

## Profiles

```bash
cd deploy/terraform/cxado-kind
terraform apply -var='profile=lite' -var='worker_replicas=1'
```

## Tear down

```bash
make cxado-tf-destroy
make cxado-kind-down
```

## Troubleshooting

| Issue | Action |
|-------|--------|
| veil-api CrashLoop | Build/load images: `make cxado-k8s-build-images`; Neo4j may need graph-bootstrap (compose runs it once) |
| egregore ImagePullBackOff | Images must be loaded into kind (`kind load docker-image`) |
| terraform/helm missing | Install terraform >= 1.5, helm 3.x |
| UI build fails | Ensure `ui/next.config.ts` has `output: standalone` and run `npm ci` locally first |

Compose dev (`make cxado-up`) is unchanged — K8s is an alternate profile.

## Known gaps (experimental)

| Gap | Workaround |
|-----|------------|
| Neo4j empty on first boot | `make cxado-graph-bootstrap` (compose) or wait for graph-bootstrap Job (k8s) |
| egregore DB schema | `uv run egregore migrate` on host, or Helm migrate Job |
| Grafana cxado dashboards | Mounted in compose; k8s uses kube-prometheus-stack scrape only until ConfigMaps wired |
| Langfuse on k8s | `enable_langfuse=true` in terraform; requires Langfuse module |
