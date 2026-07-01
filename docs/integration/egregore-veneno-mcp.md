# egregore ↔ veneno-mcp integration

**Status:** partial stub — client + HITL-gated tools; veneno stack not in `make cxado-up` by default.

## Overview

Egregore can route **execution** tools to [veneno](https://github.com/butbeautifulv/veneno) via HTTP MCP when enabled. Read-only TI remains on [veil-mcp](egregore-veil-mcp.md).

## Configuration

In `projects/egregore/.env`:

```env
VENENO_MCP_ENABLED=true
VENENO_MCP_URL=http://localhost:8093/mcp
```

Start veneno engage stack separately (see `projects/veneno/deploy/engage/`).

## Allowlisted tools

| Tool | HITL | Notes |
|------|------|-------|
| `run_active_scan` | yes | Active scan execution |
| `execute_command` | yes | Shell — policy denied by default |
| `engage_run_tool` | yes | Generic engage tool bridge |

## Smoke

```bash
USE_MEMORY_FALLBACK=true STAGE=test uv run pytest tests/tool_gateway/test_veneno_mcp_adapter.py -q
```

## Related

- [egregore-veil-mcp.md](egregore-veil-mcp.md) — graph read path
- [veneno → veil events](../../shared/contracts/README.md) — engage.events NATS wire
