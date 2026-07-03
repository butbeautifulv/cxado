# cxado integration index

Cross-project wiring runbooks. See also [ecosystem-map.md](../ecosystem-map.md).

**Visual diagrams:** [architecture-site/](../architecture-site/) — component, sequence, and deployment UML (k3s: port 30080).

| Integration | Status | Doc |
|-------------|--------|-----|
| egregore ↔ veil-mcp | **Wired** (read-only graph + playbooks) | [egregore-veil-mcp.md](egregore-veil-mcp.md) |
| veneno → veil (engage.events) | **Wired** (NATS ingest) | [shared/contracts/README.md](../../shared/contracts/README.md) |
| egregore ↔ veneno-mcp | **Partial** (client stub, HITL-gated exec) | [egregore-veneno-mcp.md](egregore-veneno-mcp.md) |
| ASOC → egregore | Planned | — |

## Default local stack

```bash
make cxado-up
make -C projects/egregore dev
```

Veil MCP: `http://localhost:8091` · Egregore API: `http://localhost:8080`
