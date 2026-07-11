# DefectDojo on k3s (greenfield)

In-cluster ASPM stack in `cxado-aspm` + Postgres in `cxado-data`. Replaces the legacy VM_01 rootless container for CI uploads.

## Deploy

```bash
# Mirror images (defectdojo-django/nginx, postgres, redis)
./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi

# Bootstrap secrets, initializer, app rollouts, API token, product egregore
./scripts/k8s/k3s-deploy-defectdojo.sh
```

Secrets and tokens are written to `deploy/.secrets/cxado-k3s.env` when the deploy script runs.

## Access

| Surface | URL |
|---------|-----|
| Admin UI (TLS gateway) | `https://<P30_NODE_IP>:30808/` — see [deploy/ports.md](../../ports.md) |
| In-cluster API (CI) | `http://defectdojo.cxado-aspm.svc.cluster.local:8080` |

Deploy applies TLS gateway via `scripts/k8s/offline-tls-apply.sh` (same stack as `k3s-deploy-defectdojo.sh`). Postgres lives in `cxado-data`; app in `cxado-aspm`.

## CI smoke

```bash
./scripts/gitlab/smoke-defectdojo-from-k3s.sh
./scripts/gitlab/setup-ci-variables.sh   # push DEFECTDOJO_* to GitLab
```

CI details: [deploy/gitlab/CI.md](../../gitlab/CI.md).

## VM_01 cutover

- Data migration from VM_01 is **out of scope** for this stack.
- After smoke on `:30808`, decommission VM_01 manually: `defectdojo-vm01-decommission.sh` (not automated).
- `defectdojo-mcp` remains on host `:8096` until a separate k3s migration.

## Manifests

| File | Purpose |
|------|---------|
| `00-namespace.yaml` | `cxado-aspm` namespace |
| `10-postgres.yaml` | Postgres in `cxado-data` |
| `11-redis.yaml` | Redis |
| `12-pvc-media.yaml` | Media uploads PVC |
| `15-initializer-job.yaml` | DB migrate + admin user |
| `20-configmap.yaml` | DefectDojo env |
| `20-defectdojo.yaml` | uwsgi, nginx, celery |
| `30-secrets.example.yaml` | Documentation only |
| `40-resource-quota.yaml` | Namespace quota |
