# GitLab CI/CD → k3s (Fabrica + Egregore secure pipeline)

Pipeline entrypoint: [`.gitlab-ci.yml`](../../.gitlab-ci.yml) → [`.gitlab/ci/cxado-k3s.gitlab-ci.yml`](../../.gitlab/ci/cxado-k3s.gitlab-ci.yml).

Project: `gitlab.svo.aero/av.popov/cxado`.

## Architecture

- **Fabrica** profile `oss-full-enterprise`: security gates, SBOM, ASPM export
- **Egregore overlay**: scoped scans on `projects/egregore`, Kaniko build, Helm deploy, smoke
- **Runner**: Kubernetes executor in `cxado-ci` namespace (tags `k3s`, `corp`, `p30`)
- **Registry**: Nexus — [`deploy/registry.defaults.env`](../registry.defaults.env)
- **DefectDojo**: product `egregore`, engagement `CI/CD`

## Stages

`validate` → `test` → `security` → `static-security-upload` → `image` (Kaniko) → `supply-chain` → `image-security-upload` → `deploy` (manual) → `smoke`

All product jobs run `./scripts/gitlab/ci-submodule-init.sh` first (`EGREGORE_ROOT=projects/egregore`).

| Job | Stage | Scope |
|-----|-------|-------|
| `lint` / `unit-test` | validate / test | egregore only |
| `gitleaks-scan`, `semgrep-sast`, `trivy-osa`, … | security | `${EGREGORE_ROOT}` |
| `upload-*-to-dojo` | static/image upload | DefectDojo product `egregore` |
| `build:egregore` | image | Kaniko → Nexus |
| `sbom-generate`, `trivy-sca` | supply-chain | built image |
| `deploy:egregore` | deploy | manual on `main` |

## One-time setup

```bash
./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi
./scripts/k8s/k3s-ansible-playbook.sh playbooks/ci-images.yml
./scripts/gitlab/setup-ci-variables.sh
./scripts/gitlab/smoke-defectdojo-from-k3s.sh
./scripts/gitlab/sync-monorepo-to-gitlab.sh --skip-submodules
```

## DefectDojo

| Variable | Default |
|----------|---------|
| `DEFECTDOJO_URL` | `http://10.20.16.195:8080` |
| `DEFECTDOJO_API_TOKEN` | auto-fetched via `setup-ci-variables.sh` (SU creds) or manual |
| `DEFECTDOJO_PRODUCT_NAME` | `egregore` |
| `DEFECTDOJO_FAIL_ON_ERROR` | `true` |

`.defectdojo_skip_rules` requires URL + token; fallback rules run uploads on MR/main.

**Pre-flight (mandatory):**

```bash
./scripts/gitlab/smoke-defectdojo-from-k3s.sh
```

If smoke fails with `connection reset` — open corp firewall **P30 pod CIDR → VM_01:8080** before trusting upload jobs.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Security scans empty / no egregore files | check `ci-submodule-init` in job log; `CI_SUBMODULES=projects/egregore` |
| `egregore submodule missing` | GitLab token access to `av.popov/egregore` submodule |
| Upload `pip` / Nexus 401 | `NEXUS_USER`/`NEXUS_PASSWORD` in GitLab vars; `.cxado_pip` netrc |
| Upload HTTP 401 | refresh token: `setup-ci-variables.sh` |
| Upload network error | `smoke-defectdojo-from-k3s.sh`; fix routing to VM_01 |
| `build:egregore` skipped | fix blocker jobs (gitleaks, semgrep, trivy-osa, unit-test) |
| ImagePullBackOff | `mirror-fabrica-ci-images.sh` + ansible `ci-images.yml` |

## Related

- [submodules.md](submodules.md)
- [README.md](README.md)
