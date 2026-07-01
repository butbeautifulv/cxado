# cxado port matrix (SSOT)

Default profile `cxado-default`: Veil graph + egregore infra + observability. Egregore app runs on the **host** (`make -C projects/egregore dev`) unless using **kind** (`make cxado-k8s-up`).

| Port | Service | Stack | Notes | k8s (kind) |
|------|---------|-------|-------|------------|
| 3000 | egregore Operator UI | host / k8s | Next.js | ingress :81 or egregore-ui SVC |
| 3001 | Langfuse UI | optional | `cxado-langfuse` profile only | — |
| 3002 | Grafana | observability | admin/admin (dev) | ingress / kube-prometheus |
| 3200 | Tempo query API | observability | |
| 4317 | Tempo OTLP gRPC | observability | `OTEL_EXPORTER_OTLP_ENDPOINT` |
| 5432 | egregore Postgres | egregore | DB `egregore` |
| 6333 | Qdrant | egregore | |
| 6379 | redis | egregore | password `password` |
| 7474 | Neo4j browser | veil | `compose.neo4j-publish` |
| 7687 | Neo4j Bolt | veil | |
| 8080 | egregore API | host / k8s | `/metrics` | ingress :80 mapping |
| 8090 | veil-api | veil | Graph HTTP API |
| 8091 | veil-mcp | veil | MCP Streamable HTTP (`--profile mcp`) |
| 8092 | egregore tool gateway | host | optional, `USE_TOOL_GATEWAY=true` |
| 9091 | Prometheus | observability | UI + `/-/reload` |
| 15432 | Langfuse Postgres | optional | localhost only |
| 16379 | Langfuse Redis | optional | localhost only |

**Avoid confusing `:9090` on host** — Langfuse MinIO uses host `9090` when the langfuse profile is enabled; Prometheus is exposed on **9091**.
