# GitLab CI/CD → k3s (corp offline)

## Project

| Field | Value |
|-------|--------|
| URL | https://gitlab.svo.aero/av.popov/cxado |
| SSH | `git@gitlab.svo.aero:av.popov/cxado.git` |
| HTTPS | `https://gitlab.svo.aero/av.popov/cxado.git` |
| Registry | `registry.svo.aero:443/av.popov/cxado` (or Nexus `:8345` mirror) |

Secrets: `deploy/.secrets/cxado-k3s.env` (`GITLAB_*`, `NEXUS_*`).

## Target cluster

| Node | Role | IP |
|------|------|-----|
| P30 (`bbv-p30-wifi`) | control-plane | `10.8.185.15` |
| VM_01 | worker | `10.20.16.195` |
| VM_02 | worker | `10.20.16.185` |

## GitLab Runner (P30)

| Item | Value |
|------|--------|
| Host | `bbv-p30-wifi` (`bbv`, shell executor) |
| Tags | `k3s`, `corp`, `p30` |
| Binary | extracted from `nexus.svo.aero:8345/gitlab/gitlab-runner:latest` (v19.1.1) |
| Service | `gitlab-runner` (user `bbv`, working dir `/home/bbv`) |
| Kubeconfig | `/home/bbv/.kube/config` on P30 |

```bash
# install / status (from laptop)
./scripts/gitlab/setup-runner-p30.sh install
./scripts/gitlab/setup-runner-p30.sh status

# after admin provides glrt- token → add GITLAB_RUNNER_TOKEN to cxado-k3s.env
./scripts/gitlab/setup-runner-p30.sh register
```

**Runner:** `p30-k3s-shell` registered (id 312, shell executor, user `bbv`).

PAT with `create_runner` scope: `./scripts/gitlab/create-gitlab-pat.sh` → save as `GITLAB_PAT_RUNNER` in `cxado-k3s.env`.

## Pipeline (`.gitlab-ci.yml`)

| Stage | Job | Notes |
|-------|-----|-------|
| validate | `validate:helm` | `helm template` egregore chart |
| build | `build:egregore` | **Kaniko Job** in `cxado-build` ns → Nexus `cxado-docker/egregore` → import all nodes |
| deploy | `deploy:egregore` | **manual** on `main` — `helm upgrade` |
| smoke | `smoke:egregore` | observability smoke test |

**CI/CD variables** (Settings → CI/CD → Variables, masked):

| Variable | Required |
|----------|----------|
| `POSTGRES_PASSWORD` | yes |
| `REDIS_PASSWORD` | yes |
| `BUS_SIGNING_KEY` | yes (or generated per deploy) |
| `CXADO_OFFLINE_SUDO_PW` | yes (for `k3s ctr import`) |
| `NEXUS_USER` | yes (Kaniko build + registry push) |
| `NEXUS_PASSWORD` | yes (Kaniko build + registry push) |

### Kaniko (in-cluster build)

Dedicated Kaniko on P30 k3s — namespace `cxado-build`, push to Nexus hosted repo `cxado-docker`.

```bash
# one-time: Nexus repo + Kaniko executor image
./scripts/k8s/nexus-cxado-docker-setup.sh --ssh bbv-p30-wifi --seed-kaniko /tmp/kaniko-executor-v1.23.2.tar

# bootstrap secrets + hostPath /var/lib/cxado/kaniko-build
./scripts/k8s/kaniko-bootstrap.sh --ssh bbv-p30-wifi
```

Corp Dockerfile: `projects/egregore/Dockerfile.corp` (Nexus base + PyPI, no BuildKit mounts).

**Submodules:** GitLab-only on `gitlab/main` — see [submodules.md](submodules.md). Sync from laptop:

```bash
./scripts/gitlab/sync-monorepo-to-gitlab.sh              # submodules + monorepo → GitLab
./scripts/gitlab/push-github.sh                          # GitHub only (unchanged)
./scripts/gitlab/push-submodule-mirror.sh projects/egregore
```

## Push monorepo

```bash
# Public dev (GitHub) — as before
./scripts/gitlab/push-github.sh

# Corp (GitLab, isolated .gitmodules)
./scripts/gitlab/sync-monorepo-to-gitlab.sh
```

Do **not** `git push gitlab main` directly — use `sync-monorepo-to-gitlab.sh` so `.gitmodules` on GitLab stays GitHub-free.

## Related

- [k3s Ansible](../ansible/k3s/README.md)
- [Nexus k3s repos](../../scripts/k8s/nexus-k3s-repos-setup.sh)
- [ports.md](../ports.md)
