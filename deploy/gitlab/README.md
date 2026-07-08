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
| build | `build:egregore` | `docker build` + `k3s ctr images import` on P30 |
| deploy | `deploy:egregore` | **manual** on `main` — `helm upgrade` |
| smoke | `smoke:egregore` | observability smoke test |

**CI/CD variables** (Settings → CI/CD → Variables, masked):

| Variable | Required |
|----------|----------|
| `POSTGRES_PASSWORD` | yes |
| `REDIS_PASSWORD` | yes |
| `BUS_SIGNING_KEY` | yes (or generated per deploy) |
| `CXADO_OFFLINE_SUDO_PW` | yes (for `k3s ctr import`) |

**Submodules:** GitHub blocked on P30 — mirrors on `gitlab.svo.aero/av.popov/*`. See [submodules.md](submodules.md). Egregore mirror: **done**.

```bash
./scripts/gitlab/push-submodule-mirror.sh projects/egregore   # refresh mirror
```

## CI/CD plan

1. ~~**GitLab Runner** on P30~~ — **done** (`p30-k3s-shell`)
2. ~~**Build** pipeline~~ — **MVP** in `.gitlab-ci.yml`
3. **Deploy** — manual job on `main`; extend for veil / MCPs later
4. **Secrets** — GitLab CI variables (see table above)

## Push monorepo (when ready)

```bash
git remote add gitlab git@gitlab.svo.aero:av.popov/cxado.git
# or HTTPS with GITLAB_TOKEN
git push gitlab main
```

Submodules: inward mirrors on `gitlab.svo.aero/av.popov/*` — see [submodules.md](submodules.md). `.gitmodules` keeps GitHub URLs for laptop dev.

## Related

- [k3s Ansible](../ansible/k3s/README.md)
- [Nexus k3s repos](../../scripts/k8s/nexus-k3s-repos-setup.sh)
- [ports.md](../ports.md)
