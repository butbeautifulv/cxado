# egregore ↔ Veil MCP integration

**Status:** wired (read path via tool gateway adapter).

## Goal

Allow egregore agents to **read** threat context via **veil-mcp** (graph queries, playbook lookup).

## Prerequisites

```bash
make bootstrap
make cxado-up
make -C projects/egregore dev
```

## Environment

In `projects/egregore/.env`:

```env
VEIL_MCP_URL=http://localhost:8091/mcp
USE_TOOL_GATEWAY=false
```

When Veil secure profile is enabled, set `VEIL_MCP_TOKEN` (or Keycloak bearer) per [veil auth docs](../../projects/veil/docs/deploy/auth-keycloak.md).

## Implementation

- MCP client: [`projects/egregore/cys_core/integrations/veil_mcp_client.py`](../../projects/egregore/cys_core/integrations/veil_mcp_client.py)
- Tool gateway adapter: [`projects/egregore/interfaces/gateways/tool/adapters/veil_mcp.py`](../../projects/egregore/interfaces/gateways/tool/adapters/veil_mcp.py)

## Veneno (execution)

Pentest execution via **veneno-mcp** remains a separate integration — see veneno deploy docs.

## References

- [cxado default stack](../deploy/cxado-default-stack.md)
- [deploy/ports.md](../../deploy/ports.md)
- [veil AGENTS.md](../../projects/veil/AGENTS.md)
