# cxado deploy

Top-level Docker Compose orchestration for the default local stack:

- **Veil** graph-only (Neo4j, veil-api, veil-mcp)
- **Egregore** infra (Postgres, Redis, Qdrant)
- **Observability** (Prometheus, Grafana, Tempo)

Egregore application processes (API, workers, UI) run on the **host** via `make -C projects/egregore dev` so Prometheus multiproc worker metrics stay aggregated on `:8080/metrics`.

## Quick start

```bash
make bootstrap          # once: submodules + symlinks
make cxado-up           # veil + egregore infra + observability
make -C projects/egregore dev   # API :8080, UI :3000, workers
make cxado-status       # health checks
```

- Grafana: http://localhost:3002 (admin/admin)
- CXado Overview dashboard: http://localhost:3002/d/cxado-overview
- Prometheus targets: http://localhost:9091/targets

## Profiles

| Profile | Command | Docker services | Host app |
|---------|---------|-----------------|----------|
| **default** | `make cxado-up` | veil + postgres + redis + **qdrant** + prometheus + grafana + **tempo** | `make -C projects/egregore dev` (4 workers) |
| **lite** | `make cxado-up-lite` | veil (capped Neo4j) + postgres + redis + **qdrant** + prometheus + grafana + **langfuse** | `WORKER_REPLICAS=1 make -C projects/egregore dev` |

Lite vs default: no **Tempo**, 1 worker, capped Neo4j, no Neo4j browser port (:7474).

Stop everything:

```bash
CXADO_STOP_VEIL=1 CXADO_STOP_LANGFUSE=1 make cxado-down
```


## Layout

```
deploy/
├── compose/           # compose overlays (shared cxado-net)
├── observability/     # unified Prometheus, Grafana, Tempo
├── profiles/          # env snippets
└── ports.md           # port SSOT
```

## Audit notes (2026)

| Gap | Status |
|-----|--------|
| No unified cxado compose | **Fixed** — `deploy/compose/` + scripts |
| Veil without `/metrics` | **Fixed** — `pkg/observability` |
| Prometheus host-only egregore | **Fixed** — unified `prometheus.yml` + veil scrape |
| No cross-platform Grafana dashboard | **Fixed** — `cxado-overview.json` |
| Langfuse bootstrap script missing in egregore | optional profile; use `make -C projects/egregore dev-langfuse` |
| Egregore app in Docker | deferred — host dev preserves multiproc metrics |

See [docs/deploy/cxado-default-stack.md](../docs/deploy/cxado-default-stack.md) for the full runbook.

## Kubernetes (kind)

> **Experimental** — health smoke works; see [known gaps](../docs/deploy/cxado-kubernetes-kind.md#known-gaps-experimental).

Alternate profile via Terraform + Helm:

```bash
make cxado-k8s-up      # kind + images + terraform apply
make cxado-k8s-status
```

Runbook: [docs/deploy/cxado-kubernetes-kind.md](../docs/deploy/cxado-kubernetes-kind.md).
