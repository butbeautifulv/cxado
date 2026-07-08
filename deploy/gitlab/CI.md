# GitLab CI/CD → k3s (Fabrica + Kaniko)

Pipeline entrypoint: [`.gitlab-ci.yml`](../../.gitlab-ci.yml) → [`.gitlab/ci/cxado-k3s.gitlab-ci.yml`](../../.gitlab/ci/cxado-k3s.gitlab-ci.yml).

Project: `gitlab.svo.aero/av.popov/cxado`.

## Architecture

- **Fabrica** profile `oss-full-enterprise`: security gates, SBOM, registry abstraction
- **cxado overlay**: Kaniko build, helm validate/deploy, smoke
- **Runner**: Kubernetes executor in `cxado-ci` namespace (tags `k8s` `corp` `cxado`)
- **Registry**: Nexus — single source of truth in [`deploy/registry.defaults.env`](../registry.defaults.env)

## Stages

`validate` → `test` → `security` → … → `image` (Kaniko) → `supply-chain` → `deploy` (manual) → `smoke`

Key jobs:

| Job | Stage | Notes |
|-----|-------|-------|
| `validate:helm` | validate | `helm template` with rendered values |
| `build:egregore` | image | Kaniko pod, push to Nexus |
| `deploy:egregore` | deploy | manual on `main` |
| `smoke:egregore` | smoke | after deploy |

## Registry configuration

All registry URLs derive from env (change once):

| File / mechanism | Variables |
|------------------|-----------|
| [`deploy/registry.defaults.env`](../registry.defaults.env) | `NEXUS_DOCKER_REGISTRY`, `NEXUS_PYPI_HOST`, `NEXUS_CXADO_DOCKER_REPO` |
| GitLab CI/CD vars | seeded by `setup-ci-variables.sh` |
| [`.gitlab/jobs/cxado/_variables.yml`](../../.gitlab/jobs/cxado/_variables.yml) | `CXADO_CI_REGISTRY`, `OSS_*_IMAGE`, `CXADO_IMAGE_REPO` |
| Helm values | placeholders `__CXADO_IMAGE_REPO__` → `render-egregore-values.sh` |

Override corp endpoints only in `deploy/.secrets/cxado-k3s.env` or GitLab CI/CD settings.

## One-time setup

```bash
# 1. Mirror CI images to Nexus
./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi

# 2. GitLab Runner (kubernetes executor in k3s)
./scripts/gitlab/setup-runner-k8s.sh --ssh bbv-p30-wifi bootstrap

# 3. k3s node registry config (Ansible)
./scripts/k8s/k3s-ansible-playbook.sh site.yml

# 4. GitLab CI/CD variables (registry + secrets + KUBECONFIG file)
./scripts/gitlab/setup-ci-variables.sh

# 5. Sync monorepo to corp GitLab
./scripts/gitlab/sync-monorepo-to-gitlab.sh
```

Legacy shell runner (`p30-k3s-shell`) — ops/bootstrap only, not used by pipeline jobs.

## CI/CD variables

| Variable | Purpose |
|----------|---------|
| `NEXUS_DOCKER_REGISTRY` | Docker Hub proxy (e.g. `nexus.svo.aero:8345`) |
| `NEXUS_DOCKER_GROUP_REGISTRY` | Docker-SEPS group for gcr/ghcr (e.g. `nexus.svo.aero:8374`) |
| `NEXUS_CXADO_DOCKER_REPO` | Hosted repo name (`cxado-docker`) |
| `NEXUS_PYPI_HOST` / `NEXUS_PYPI_REPO` | Kaniko build-args |
| `NEXUS_USER` / `NEXUS_PASSWORD` | Registry auth |
| `KUBECONFIG` | file — cluster access for deploy/smoke |
| `POSTGRES_PASSWORD` / `REDIS_PASSWORD` / `BUS_SIGNING_KEY` | Helm deploy |

Seed all: `./scripts/gitlab/setup-ci-variables.sh`

## Trigger pipeline

GitLab UI → CI/CD → Run pipeline on `main`, or API from P30.

`deploy:egregore` is **manual** on `main`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Jobs stuck (no runner) | `kubectl -n cxado-ci get pods`; `setup-runner-k8s.sh status` |
| `missing KUBECONFIG` | `setup-ci-variables.sh` (uploads file var) |
| Kaniko push fails | check `NEXUS_*` vars; Nexus CA mounted on runner pods |
| Wrong image path in helm | check `NEXUS_DOCKER_REGISTRY` in GitLab vars |
| Security job `ImagePullBackOff` | `mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi` + ansible `playbooks/ci-images.yml` (podman on RED OS VMs, docker on P30) |
| DefectDojo upload skipped | `DEFECTDOJO_URL` + `DEFECTDOJO_API_TOKEN` via `setup-ci-variables.sh` |

## DefectDojo upload

| Variable | Default |
|----------|---------|
| `DEFECTDOJO_URL` | `http://10.20.16.195:8080` |
| `DEFECTDOJO_API_TOKEN` | API key from DefectDojo UI |
| `DEFECTDOJO_PRODUCT_NAME` | `cxado` |

Seed: `./scripts/gitlab/setup-ci-variables.sh`  
Pre-flight: `./scripts/gitlab/smoke-defectdojo-from-k3s.sh`

## Related

- [submodules.md](submodules.md)
- [README.md](README.md)
- [registry.defaults.env.example](../registry.defaults.env.example)
