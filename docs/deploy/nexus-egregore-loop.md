# Nexus egregore build loop (P30 Kaniko)

Single-command deploy for egregore **api + worker + ui** via Nexus — no `docker save`, no `k3s-distribute-image.sh`.

## Prerequisites (one-time)

```bash
./scripts/k8s/nexus-cxado-docker-setup.sh
./scripts/k8s/kaniko-bootstrap.sh
./scripts/k8s/nexus-npm-go-proxy-setup.sh --ssh bbv-p30-wifi   # npm-proxy for bun install (UI)
ansible-playbook deploy/ansible/k3s/playbooks/ci-images.yml   # registries.yaml on all nodes
./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi  # includes oven-bun for UI
./scripts/k8s/nexus-bootstrap-verify.sh
./scripts/k8s/nexus-bootstrap-verify.sh --worker vm-01
```

Secrets: `deploy/.secrets/cxado-k3s.env` (`NEXUS_PASSWORD`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, …).

## Daily loop

```bash
# commit projects/egregore first (dirty-tree guard)
TAG="$(git -C projects/egregore rev-parse --short HEAD)"
./scripts/k8s/cxado-nexus-deploy.sh --build --tag "${TAG}"
```

What it does:

1. `rsync` `projects/egregore/` → `P30:/var/lib/cxado/kaniko-build/egregore/`
2. Kaniko Job in `cxado-build` → push `nexus.svo.aero:8345/cxado-docker/egregore:${TAG}` and `…/egregore-ui:${TAG}`
3. `egregore-helm-upgrade.sh` with Nexus repos + `imagePullSecrets: nexus-registry`

Re-deploy without rebuild:

```bash
./scripts/k8s/cxado-nexus-deploy.sh --skip-build --tag "${TAG}"
```

## UI build options

| Mode | Command |
|------|---------|
| Full Kaniko UI build | default in `cxado-nexus-deploy.sh --build` |
| Prebuilt `.next` on laptop | `cd projects/egregore/web_ui && bun run build` then `--build --prebuilt-ui` |
| Backend only | `kaniko-build-egregore.sh --backend-only --tag "${TAG}"` |

Corp Dockerfiles: `projects/egregore/Dockerfile.corp`, `projects/egregore/web_ui/Dockerfile.corp`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ImagePullBackOff` on api/worker/ui | Confirm tag in Nexus; `k3s ctr images pull nexus.svo.aero:8345/cxado-docker/egregore:${TAG}` on node |
| Kaniko Job `hostPath` not found | Run `kaniko-bootstrap.sh`; rsync must land on control-plane (`nodeSelector`) |
| UI Kaniko fails on `oven/bun` | Run `mirror-fabrica-ci-images.sh` (oven-bun:1-alpine) |
| UI `bun install` hangs / hits npmjs.org directly | Run `nexus-npm-go-proxy-setup.sh`; UI build now routes through `NEXUS_NPM_HOST`/`NEXUS_NPM_REPO` (no direct internet from the Kaniko pod) |
| UI OOM | `--prebuilt-ui` after local `bun run build` |
| Dirty tree guard | Commit egregore or `CXADO_ALLOW_DIRTY_BUILD=1` |

## Deprecated path

Tar bundle scripts for **app images** were removed. Use `cxado-nexus-deploy.sh`.

Infra-only tar import: `k3s-offline-bundle-infra.sh` (see [nexus-veil-loop.md](nexus-veil-loop.md)).

## Related

- Registry SSOT: [deploy/registry.defaults.env](../../deploy/registry.defaults.env)
- Offline baseline: [k3s-offline-baseline.md](k3s-offline-baseline.md)
- Rollout diagnosis: [k3s-rollout-pending-diagnosis.md](../observability/k3s-rollout-pending-diagnosis.md)
