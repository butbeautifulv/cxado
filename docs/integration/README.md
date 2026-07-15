# cxado integration index

Cross-project wiring runbooks. See also [ecosystem-map.md](../ecosystem-map.md) and [DOCUMENTATION.md](../DOCUMENTATION.md).

**Visual diagrams:** [architecture-site/](../architecture-site/) — k3s port 30080.

| Integration | Status | Doc |
|-------------|--------|-----|
| egregore ↔ veil-mcp | **Wired** (read-only graph + playbooks) | [egregore-veil-mcp.md](egregore-veil-mcp.md) |
| veneno → veil (engage.events) | **Wired** (NATS ingest) | [shared/contracts/README.md](../../shared/contracts/README.md) |
| egregore ↔ veneno-mcp | **Partial** (client stub, HITL-gated exec) | [egregore-veneno-mcp.md](egregore-veneno-mcp.md) |
| egregore ↔ maxpatrol-siem-mcp | **Wired** (SOC SIEM tools) | [egregore-siem-mcp.md](egregore-siem-mcp.md) |
| egregore ↔ tenable-mcp | **Wired** (Nessus inventory) | [egregore-tenable-mcp.md](egregore-tenable-mcp.md) |
| egregore ↔ defectdojo-mcp | **Wired** (ASPM findings) | [deploy/k8s/defectdojo-offline/README.md](../../deploy/k8s/defectdojo-offline/README.md) |

Local stack: [README.md](../../README.md#default-local-stack) · Veil MCP `:8091` · Egregore API `:8080`
