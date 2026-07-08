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

**Instance policy:** `gitlab.svo.aero` blocks runner creation by project members (`Please contact an admin to create runners`). Shared runners are **enabled** on the project — jobs can use instance runners (`kubernetes`, `docker`, `cd-runner` tags) until a dedicated P30 runner is registered.

PAT with `create_runner` scope: `./scripts/gitlab/create-gitlab-pat.sh` → save as `GITLAB_PAT_RUNNER` in `cxado-k3s.env`.

## CI/CD plan

1. ~~**GitLab Runner** on P30~~ — **installed**, pending `GITLAB_RUNNER_TOKEN` from admin
2. **Build** — `docker build` / `podman build`, push to `nexus.svo.aero:8345/av.popov/cxado/<image>`
3. **Deploy** — `helm upgrade` / `kubectl apply` via kubeconfig on runner (`/home/bbv/.kube/config` on P30)
4. **Secrets** — GitLab CI variables (masked): `NEXUS_PASSWORD`, `KUBECONFIG` base64, app secrets

## Push monorepo (when ready)

```bash
git remote add gitlab git@gitlab.svo.aero:av.popov/cxado.git
# or HTTPS with GITLAB_TOKEN
git push gitlab main
```

Submodules: decide mirror vs `git submodule` URLs pointing at GitLab forks.

## Related

- [k3s Ansible](../ansible/k3s/README.md)
- [Nexus k3s repos](../../scripts/k8s/nexus-k3s-repos-setup.sh)
- [ports.md](../ports.md)
