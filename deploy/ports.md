# cxado port matrix (SSOT)

Default profile `cxado-default`: Veil graph + egregore infra + observability. Egregore app runs on the **host** (`make -C projects/egregore dev`) unless using **kind** (`make cxado-k8s-up`).

| Port | Service | Stack | Notes | k8s (kind) |
|------|---------|-------|-------|------------|
| 3000 | egregore Operator UI (Next.js) | host only | `make -C projects/egregore dev` / local `npm run dev` | — |
| 30300 | egregore API + ui-minimal | k3s offline | TLS gateway: API paths (`/v1/`, `/health`, `/metrics`) + static ui-minimal | egregore-ui-minimal SVC |
| 30301 | egregore Operator UI (Next.js) | k3s offline | Helm `egregore-ui`; API via in-cluster `/api/egregore` proxy | egregore-ui SVC |
| 30001 | Langfuse UI | k3s offline | TLS gateway | langfuse SVC |
| 30002 | Grafana | k3s offline | TLS gateway | grafana.cxado-obs |
| 30091 | Prometheus UI | k3s offline | TLS gateway | prometheus.cxado-obs |
| 30880 | Metrics / API gateway | k3s offline | TLS gateway (egregore API alternate) | cxado-tls-gateway |
| 30990 | veil-api | k3s offline | TLS gateway | veil-api |
| 30991 | veil-mcp | k3s offline | TLS gateway | veil-mcp |
| 30474 | Neo4j browser | k3s offline | TLS gateway | neo4j |
| 3001 | Langfuse UI | optional | `cxado-langfuse` profile only | — |
| 3002 | Grafana | observability | admin/admin (dev) | ingress / kube-prometheus |
| 30080 | Architecture docs site | k3s offline | Static HTML + Mermaid; TLS via `cxado-tls-gateway`; hostPath `/home/bbv/cxado/arch-docs` | cxado-arch-docs SVC |
| 3200 | Tempo query API | observability | |
| 4317 | Tempo OTLP gRPC | observability | `OTEL_EXPORTER_OTLP_ENDPOINT` |
| 5432 | egregore Postgres | egregore | DB `egregore` |
| 6333 | Qdrant | egregore | |
| 6379 | redis | egregore | password `password` |
| 7474 | Neo4j browser | veil | `compose.neo4j-publish` |
| 7687 | Neo4j Bolt | veil | |
| 8080 | egregore API | host / k8s | `/metrics`; operator follow-ups `GET/POST /v1/work-orders/{id}/follow-ups` | ingress :80 mapping |
| 8090 | veil-api | veil | Graph HTTP API |
| 8091 | veil-mcp | veil | MCP Streamable HTTP (`--profile mcp`) |
| 8092 | egregore tool gateway | host | optional, `USE_TOOL_GATEWAY=true` |
| 8094 | maxpatrol-siem-mcp | host | optional, `make cxado-up-siem-mcp` |
| 8095 | tenable-mcp (Nessus) | host | optional, local Nessus REST MCP |
| 30808 | defectdojo UI | k3s offline | ASPM admin; TLS via `cxado-tls-gateway` | defectdojo.cxado-aspm |
| 8096 | defectdojo-mcp | host | optional, DefectDojo API v2 MCP |
| 9091 | Prometheus | observability | UI + `/-/reload` |
| 15432 | Langfuse Postgres | optional | localhost only |
| 16379 | Langfuse Redis | optional | localhost only |

## GPU host (phy-gpu-host01 — offline vLLM)

| Port | Service | Host | Notes |
|------|---------|------|-------|
| 11611 | vLLM API + `/metrics` | 10.8.185.185 | egregore `LLM_BASE_URL`; Prometheus `job=vllm` |
| 9100 | node-exporter | 10.8.185.185 | Host CPU/RAM; `job=proxmox-gpu-node`; install via `scripts/obs/install-gpu-host-exporters.sh` |
| 9400 | dcgm-exporter | 10.8.185.185 | GPU util/VRAM; `job=proxmox-gpu-dcgm` |

SSOT: `docs/observability/gpu-host-ssot.md`. Scraper: k3s P30 `10.8.185.15` → GPU VM.

**Avoid confusing `:9090` on host** — Langfuse MinIO uses host `9090` when the langfuse profile is enabled; Prometheus is exposed on **9091**.
