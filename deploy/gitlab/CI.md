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
./scripts/k8s/k3s-deploy-defectdojo.sh
./scripts/k8s/k3s-ansible-playbook.sh playbooks/ci-images.yml
./scripts/gitlab/setup-ci-variables.sh
./scripts/gitlab/smoke-defectdojo-from-k3s.sh
./scripts/gitlab/sync-monorepo-to-gitlab.sh --skip-submodules
```

## DefectDojo (k3s `cxado-aspm`)

Greenfield in-cluster deploy (no VM_01 data migration). See [`deploy/k8s/defectdojo-offline/README.md`](../k8s/defectdojo-offline/README.md).

```bash
./scripts/k8s/k3s-deploy-defectdojo.sh
# gateway NodePort 30808 is applied by the deploy script
```

| Variable | Default |
|----------|---------|
| `DEFECTDOJO_URL` | `http://defectdojo.cxado-aspm.svc.cluster.local:8080` |
| `DEFECTDOJO_API_TOKEN` | bootstrap via `k3s-deploy-defectdojo.sh` or `setup-ci-variables.sh` |
| `DEFECTDOJO_PRODUCT_NAME` | `egregore` |
| Admin UI | `https://<P30_NODE_IP>:30808/` |

VM_01 decommission is manual after smoke (`defectdojo-vm01-decommission.sh`).

**Pre-flight (mandatory):**

```bash
./scripts/gitlab/smoke-defectdojo-from-k3s.sh
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Security scans empty / no egregore files | check `ci-submodule-init` in job log; `CI_SUBMODULES=projects/egregore` |
| `egregore submodule missing` | GitLab token access to `av.popov/egregore` submodule |
| Upload `pip` / Nexus 401 | `NEXUS_USER`/`NEXUS_PASSWORD` in GitLab vars; `.cxado_pip` netrc |
| Upload HTTP 401 | refresh token: `setup-ci-variables.sh` |
| Upload network error | `k3s-deploy-defectdojo.sh`; `smoke-defectdojo-from-k3s.sh` (in-cluster URL) |
| `build:egregore` skipped | fix blocker jobs (gitleaks, semgrep, trivy-osa, unit-test) |
| Trivy `mirror.gcr.io` / vulndb FATAL | set `TRIVY_DB_REPOSITORY=${NEXUS_DOCKER_GROUP_REGISTRY}/aquasecurity/trivy-db`; mount Nexus CA (`SSL_CERT_FILE`); run `mirror-fabrica-ci-images.sh` vulndb verify |
| ImagePullBackOff | `mirror-fabrica-ci-images.sh` + ansible `ci-images.yml` |

## k3s baseline (manual, optional)

Repeatable Prometheus + kubectl snapshot for bottleneck tracking (Phase 0). Not a blocking CI gate.

```bash
make k3s-baseline-critical   # from runner or dev machine with P30 network access
make k3s-cluster-snapshot
```

Artifacts: `deploy_logs/k3s-baseline/` (gitignored). Docs: [`docs/observability/k3s-bottleneck-slo.md`](../../docs/observability/k3s-bottleneck-slo.md).

Suggested GitLab job (manual / scheduled): run `make k3s-baseline-critical` with `CXADO_NODE_IP` from CI variables after deploy smoke.

## Egregore deploy / rollout (Phase 5)

**Production model (offline P30):**

| Tier | Component | Deploy path |
|------|-----------|-------------|
| **Critical** | api + worker + ui | [nexus-egregore-loop.md](../../docs/deploy/nexus-egregore-loop.md) — `cxado-nexus-deploy.sh` |
| **Veil** | veil-api + veil-mcp | [nexus-veil-loop.md](../../docs/deploy/nexus-veil-loop.md) — `cxado-nexus-deploy-veil.sh` |
| **Fallback** | tar import | `k3s-offline-bundle-*.sh` — **DEPRECATED** |

```bash
TAG=offline-$(date +%Y%m%d)
./scripts/k8s/cxado-nexus-deploy.sh --build --tag "$TAG"
./scripts/k8s/egregore-helm-upgrade.sh   # if not part of deploy script
```

**Rollback:**

```bash
ssh bbv-p30-wifi 'KUBECONFIG=/home/bbv/.kube/config helm rollback egregore -n cxado-app'
./scripts/k8s/verify-egregore-rollout.sh
```

| Script | Gate | Scope |
|--------|------|-------|
| `k3s-image-imported.sh` | preflight | image in k3s containerd |
| `egregore-helm-upgrade.sh` | orchestrator | no `--wait`; secrets always set |
| `verify-egregore-rollout.sh` | **blocking** | api + worker |
| `verify-egregore-ui-rollout.sh` | blocking if `ui.replicas>0` | Next.js UI only |
| `diagnose-pending-pods.sh` | diagnostic | scheduler / quota |

## Related

- [submodules.md](submodules.md)
- [README.md](README.md)
