# Optional observability (offline): Tempo / Loki / Langfuse

These components are intentionally **optional** and should be enabled only after core health is stable.

## Tempo (traces)

Included offline-ready manifests:
- `deploy/k8s/obs-offline/30-tempo.yaml`

ConfigMap bootstrap:
- `./scripts/k8s/obs-create-configmaps.sh` also creates `tempo-config` from `deploy/observability/tempo/tempo.yaml`

Egregore exports OTLP spans when `OTEL_ENABLED=true` and `OTEL_EXPORTER_OTLP_ENDPOINT` points at Tempo (see `deploy/k8s/cxado-offline/values-egregore-offline.yaml`).

## Loki (logs)

Offline manifests:
- `deploy/k8s/obs-offline/31-loki.yaml` — Loki single-binary + PVC
- `deploy/k8s/obs-offline/32-promtail.yaml` — Promtail DaemonSet (pod log shipping)
- `deploy/observability/loki/loki.yaml` — Loki config
- `deploy/observability/promtail/promtail.yaml` — Promtail pipeline (JSON parse for egregore)

Grafana datasource provisioning includes Loki + Tempo `tracesToLogsV2` correlation.

Images (pre-import via bundle script):
- `grafana/loki:3.4.2`
- `grafana/promtail:3.4.2`

```bash
./scripts/k8s/k3s-offline-bundle-obs.sh
./scripts/k8s/obs-create-configmaps.sh
kubectl apply -f deploy/k8s/obs-offline/31-loki.yaml
kubectl apply -f deploy/k8s/obs-offline/32-promtail.yaml
```

## Langfuse (LLM tracing UI)

Reference compose stack:
- `projects/egregore/deploy/langfuse/docker-compose.yml`

Offline considerations:
- dependencies: Postgres + Redis + ClickHouse + MinIO + bucket init job
- define storage PVCs and secrets (SALT, ENCRYPTION_KEY, NEXTAUTH_SECRET, MinIO creds, DB creds)
- pre-import all images:
  - `langfuse/langfuse:3`
  - `langfuse/langfuse-worker:3`
  - `clickhouse/clickhouse-server`
  - `minio/minio`, `minio/mc`
  - `redis:7`, `postgres:<pinned>`

For k3s, prefer implementing Langfuse as a separate “langfuse-offline” directory with:
- manifests for each dependency
- a `create-secrets.sh` script (keeps secrets out of git)
- a dedicated image-bundle script similar to `k3s-offline-bundle-min.sh`

## Full observability deploy (k3s offline)

`scripts/k8s/k3s-deploy-cxado-offline.sh` applies Prometheus, Grafana, Tempo, Loki, Promtail and refreshes all observability ConfigMaps. Grafana dashboard **Egregore / Observability** (`egregore-observability.json`) combines metrics, logs, and traces.
