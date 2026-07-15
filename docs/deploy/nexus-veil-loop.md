# Nexus veil build loop (P30 Kaniko)

Single-command deploy for veil **graph plane** (veil-api + veil-mcp) via Nexus — no `docker build` on laptop, no `docker save`, no `k3s ctr import` for app images.

## Prerequisites (one-time)

Shared Nexus bootstrap (same as egregore):

```bash
./scripts/k8s/nexus-cxado-docker-setup.sh
./scripts/k8s/kaniko-bootstrap.sh          # includes nexus-registry in namespace veil
./scripts/k8s/nexus-npm-go-proxy-setup.sh --ssh bbv-p30-wifi   # go-proxy for go build (api/mcp)
ansible-playbook deploy/ansible/k3s/playbooks/ci-images.yml
./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi  # golang + distroless
./scripts/k8s/nexus-bootstrap-verify.sh
```

Playbooks hostPath on control-plane (required for veil-api search):

```bash
# via ansible site.yml, or:
./scripts/veil/bootstrap-skills-index-hostpath.sh --ssh bbv-p30-wifi
```

Ensure `/var/lib/veil/playbooks/docs/skills-index` and `corpus/` exist on the control-plane node.

Secrets: `deploy/.secrets/cxado-k3s.env` (`NEXUS_PASSWORD`, …).

Greenfield data plane (first install only):

```bash
VEIL_OFFLINE_TAG=offline-$(date +%Y%m%d) ./scripts/k8s/k3s-deploy-veil-offline.sh --no-smoke
```

## Daily loop

```bash
# commit projects/veil first (dirty-tree guard)
TAG="$(git -C projects/veil rev-parse --short HEAD)"
./scripts/k8s/cxado-nexus-deploy-veil.sh --build --tag "${TAG}"
```

What it does:

1. `rsync` `projects/veil/` → `P30:/var/lib/cxado/kaniko-build/veil/`
2. Kaniko Jobs in `cxado-build` → push `nexus.svo.aero:8345/cxado-docker/veil-api:${TAG}` and `…/veil-mcp:${TAG}`
3. `veil-helm-upgrade.sh` with Nexus `imageRegistry` + `imagePullSecrets: nexus-registry`

Re-deploy without rebuild:

```bash
./scripts/k8s/cxado-nexus-deploy-veil.sh --skip-build --tag "${TAG}"
```

Build options:

| Mode | Command |
|------|---------|
| Full api + mcp | default in `cxado-nexus-deploy-veil.sh --build` |
| API only | `kaniko-build-veil.sh --api-only --tag "${TAG}"` |
| MCP only | `kaniko-build-veil.sh --mcp-only --tag "${TAG}"` |

Corp Dockerfiles: `projects/veil/deploy/knowledge/docker/api.Dockerfile.corp`, `mcp.Dockerfile.corp`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ImagePullBackOff` on veil-api/mcp | Confirm tag in Nexus; `k3s ctr images pull nexus.svo.aero:8345/cxado-docker/veil-api:${TAG}` on control-plane |
| Kaniko Job `hostPath` not found | Run `kaniko-bootstrap.sh`; rsync must land on control-plane (`nodeSelector`) |
| Kaniko fails on golang/distroless | Run `mirror-fabrica-ci-images.sh` (golang-1.25-bookworm, distroless-static-debian12) |
| `go build` EOF / truncated module download | Run `nexus-npm-go-proxy-setup.sh`; build now routes through `NEXUS_GO_HOST`/`NEXUS_GO_REPO` instead of `proxy.golang.org` directly |
| veil-api CrashLoop (playbooks) | Check `/var/lib/veil/playbooks` hostPath on control-plane |
| Dirty tree guard | Commit veil or `CXADO_ALLOW_DIRTY_BUILD=1` |

## Deprecated path

Tar bundle for veil-api/mcp:

- `k3s-offline-bundle-min.sh` (veil build section) — still used for nats/neo4j tar only

Prefer `cxado-nexus-deploy-veil.sh`.

## Related

- Egregore loop: [nexus-egregore-loop.md](nexus-egregore-loop.md)
- Registry SSOT: [deploy/registry.defaults.env](../../deploy/registry.defaults.env)
- Offline baseline: [k3s-offline-baseline.md](k3s-offline-baseline.md)
- Rollout diagnosis: [k3s-rollout-pending-diagnosis.md](../observability/k3s-rollout-pending-diagnosis.md)
