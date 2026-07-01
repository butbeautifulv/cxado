# cxado default stack

Single entrypoint for local development: **egregore + Veil (graph) + observability**.

## Prerequisites

- Docker Engine + Compose v2
- `make bootstrap` from repo root
- Python/uv for egregore (`projects/egregore`)
- Optional: local vLLM or cloud LLM keys in `projects/egregore/.env`

## Bring up

```bash
# 1. Shared infrastructure + observability
make cxado-up

# 2. Egregore app (host — API, workers, UI)
make -C projects/egregore dev
```

## Profiles

| Profile | Command | Docker services | Host app |
|---------|---------|-----------------|----------|
| **default** | `make cxado-up` | veil + postgres + redis + qdrant + prometheus + grafana + tempo | `make -C projects/egregore dev` |
| **lite** | `make cxado-up-lite` | veil (capped Neo4j) + postgres + redis + qdrant + prometheus + grafana + langfuse | `WORKER_REPLICAS=1 make -C projects/egregore dev` |

Lite omits **Tempo** only; Langfuse and Qdrant are included. Default uses 4 workers and full Neo4j/Tempo.

Stop: `CXADO_STOP_VEIL=1 CXADO_STOP_LANGFUSE=1 make cxado-down`


All containers attach to Docker network **`cxado-net`**.

### Endpoints

| URL | Purpose |
|-----|---------|
| http://localhost:8090/health | veil-api |
| http://localhost:8091/health | veil-mcp |
| http://localhost:8080/health | egregore API (after `dev`) |
| http://localhost:3000 | Operator UI |
| http://localhost:3002 | Grafana |
| http://localhost:9091/targets | Prometheus targets |
| http://localhost:3002/d/cxado-overview | Platform dashboard |

Port reference: [deploy/ports.md](../../deploy/ports.md).

## Egregore ↔ Veil

Set in `projects/egregore/.env`:

```env
VEIL_MCP_URL=http://localhost:8091/mcp
USE_TOOL_GATEWAY=false
```

See [integration/egregore-veil-mcp.md](../integration/egregore-veil-mcp.md).

## Observability

- **Prometheus** scrapes egregore API on `host.docker.internal:8080` and Veil services on `cxado-net`.
- **Grafana** folders: CXado (overview), Egregore, Veil.
- Reload Prometheus after config change: `make cxado-obs-reload`

Optional LLM traces: `make cxado-up-langfuse` or `make -C projects/egregore dev-langfuse`.

## Tear down

```bash
make cxado-down              # stops obs + egregore infra; keeps veil by default
make cxado-down CXADO_STOP_VEIL=1   # also stops veil graph
```

Data volumes are preserved unless you pass `docker compose down -v` manually.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| veil-api DOWN in Grafana | `docker compose -f deploy/compose/veil-graph.yml --profile mcp ps` |
| egregore-api DOWN | Run `make -C projects/egregore dev`; curl :8080/health |
| veil-mcp DOWN | MCP profile: `docker compose ... --profile mcp up -d mcp` |
| Port conflict :8090 | Another stack (Langfuse MinIO uses :9090, not :8090) |
