# GitLab CI/CD → k3s (corp offline)

## Project

| Field | Value |
|-------|--------|
| URL | https://gitlab.svo.aero/av.popov/cxado |
| SSH | `git@gitlab.svo.aero:av.popov/cxado.git` |
| HTTPS | `https://gitlab.svo.aero/av.popov/cxado.git` |
| Docker registry | `${NEXUS_DOCKER_REGISTRY}/${NEXUS_CXADO_DOCKER_REPO}` — see [registry.defaults.env](../registry.defaults.env) |

Secrets: `deploy/.secrets/cxado-k3s.env` (`GITLAB_*`, `NEXUS_*`).

## Target cluster

| Node | Role | IP |
|------|------|-----|
| P30 (`bbv-p30-wifi`) | control-plane | `10.8.185.15` |
| VM_01 | worker (legacy DefectDojo host — **decommissioned** after in-cluster ASPM) | `10.20.16.195` |
| VM_02 | worker | `10.20.16.185` |

DefectDojo runs in-cluster on TLS gateway `:30808` — see [deploy/k8s/defectdojo-offline/README.md](../k8s/defectdojo-offline/README.md). VM_01 cutover: `scripts/k8s/defectdojo-vm01-decommission.sh`.

## GitLab Runner (kubernetes executor)

| Item | Value |
|------|--------|
| Namespace | `cxado-ci` on P30 k3s |
| Tags | `k8s`, `corp`, `cxado` |
| Image | `${NEXUS_DOCKER_REGISTRY}/gitlab/gitlab-runner:latest` |
| Manifests | [deploy/k8s/gitlab-runner/](../k8s/gitlab-runner/) |

```bash
# bootstrap runner in cluster
./scripts/gitlab/setup-runner-k8s.sh --ssh bbv-p30-wifi bootstrap
./scripts/gitlab/setup-runner-k8s.sh --ssh bbv-p30-wifi status
```

Legacy shell runner (`p30-k3s-shell`) — ops/bootstrap only. Install: `./scripts/gitlab/setup-runner-p30.sh`.

## Pipeline

Fabrica `oss-full-enterprise` + cxado Kaniko overlay. Details: [CI.md](CI.md).

| Stage | Key jobs |
|-------|----------|
| validate | `validate:helm`, fabrica lint |
| security | gitleaks, semgrep, trivy-osa, checkov, … |
| image | `build:egregore` (Kaniko → Nexus) |
| deploy | `deploy:egregore` (manual) |
| smoke | `smoke:egregore` |

```bash
# CI images → Nexus
./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi

# GitLab CI/CD variables (registry + secrets + KUBECONFIG file)
./scripts/gitlab/setup-ci-variables.sh

# Sync monorepo to corp GitLab
./scripts/gitlab/sync-monorepo-to-gitlab.sh
```

## Registry (change once)

| File | Purpose |
|------|---------|
| [deploy/registry.defaults.env](../registry.defaults.env) | `NEXUS_DOCKER_REGISTRY`, `NEXUS_PYPI_HOST`, `CXADO_CI_REGISTRY` |
| [deploy/registry.defaults.env.example](../registry.defaults.env.example) | template for secrets overlay |

## Push monorepo

```bash
./scripts/gitlab/push-github.sh              # GitHub (public dev)
./scripts/gitlab/sync-monorepo-to-gitlab.sh  # corp GitLab (isolated .gitmodules)
```

Do **not** `git push gitlab main` directly — use `sync-monorepo-to-gitlab.sh`.

## Related

- [CI.md](CI.md)
- [submodules.md](submodules.md)
- [k3s Ansible](../ansible/k3s/README.md)
- [ports.md](../ports.md)
