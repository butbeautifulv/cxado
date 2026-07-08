# GitLab CI/CD → k3s (P30)

Pipeline: `.gitlab-ci.yml` on `gitlab.svo.aero/av.popov/cxado`.

## Flow

```
push gitlab/main
  → validate:helm     (helm template)
  → build:egregore    (Kaniko Job in cxado-build → Nexus → import nodes)
  → deploy:egregore   (manual) helm upgrade
  → smoke:egregore    (observability smoke)
```

Runner: `p30-k3s-shell` on `bbv-p30-wifi` (shell, tags `k3s` `corp` `p30`).

## One-time setup

```bash
# 1. Runner (if not done)
./scripts/gitlab/setup-runner-p30.sh register

# 2. Kaniko namespace + Nexus secrets on k3s
./scripts/k8s/kaniko-bootstrap.sh --ssh bbv-p30-wifi

# 3. Kaniko executor in containerd (optional if already imported)
./scripts/k8s/nexus-cxado-docker-setup.sh --ssh bbv-p30-wifi --seed-kaniko /tmp/kaniko-executor-v1.23.2.tar

# 4. GitLab CI/CD variables from deploy/.secrets/cxado-k3s.env
./scripts/gitlab/setup-ci-variables.sh

# 5. GitLab mirrors (submodules)
./scripts/gitlab/bootstrap-gitlab-mirrors.sh
./scripts/gitlab/sync-monorepo-to-gitlab.sh
```

## CI/CD variables (auto via setup-ci-variables.sh)

| Variable | Purpose |
|----------|---------|
| `POSTGRES_PASSWORD` | egregore helm |
| `REDIS_PASSWORD` | egregore helm |
| `BUS_SIGNING_KEY` | egregore helm |
| `CXADO_OFFLINE_SUDO_PW` | sudo on P30 (kaniko hostPath, ctr import) |
| `NEXUS_USER` / `NEXUS_PASSWORD` | Kaniko build + registry push |
| `VM_01_PWD` / `VM_02_PWD` | image import on workers (optional) |

## Trigger pipeline

```bash
# after sync to gitlab
ssh bbv-p30-wifi "curl -sk --request POST \
  --header 'PRIVATE-TOKEN: \$GITLAB_PAT_RUNNER' \
  '${GITLAB_URL}/api/v4/projects/1938/pipeline' \
  -d 'ref=main'"
```

Or: GitLab UI → CI/CD → Run pipeline.

## Deploy

`deploy:egregore` is **manual** on `main`. After build succeeds, click Play in GitLab.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `missing NEXUS_USER` | `./scripts/gitlab/setup-ci-variables.sh` |
| `Host key verification failed` (submodule) | fixed: CI uses job token HTTPS |
| Kaniko Job `ImagePullBackOff` | import executor: `nexus-cxado-docker-setup.sh` or use gcr.io image in containerd |
| `docker pull` Nexus fails | build uses `k3s ctr pull` instead |

## Related

- [submodules.md](submodules.md)
- [README.md](README.md)
