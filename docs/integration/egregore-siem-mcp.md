# egregore ↔ MaxPatrol SIEM MCP integration

**Status:** wired (read-only SIEM tools via `siem_mcp_client`).

## Goal

Allow egregore SOC agents to **read** MaxPatrol SIEM data (incidents, events, assets) via **maxpatrol-siem-mcp** with Langfuse `tool.invoke` tracing.

## Prerequisites

```bash
make bootstrap
# Configure deploy/.secrets/siem-mcp.env (SIEM_BASE_URL, credentials, SIEM_READONLY=true)
./scripts/k8s/k3s-deploy-siem-mcp.sh
# Then upgrade egregore (siem.mcpEnabled in values-egregore-offline.yaml)
```

For local dev without k8s:

```bash
# Configure projects/maxpatrol-siem-mcp/.env
make cxado-up-siem-mcp
make -C projects/egregore dev
```

## Environment

In `projects/egregore/.env`:

```env
SIEM_MCP_ENABLED=true
SIEM_MCP_URL=http://localhost:8094/mcp
SIEM_MCP_TIMEOUT=180
```

`query_siem_readonly` delegates to `search_events` when `SIEM_MCP_ENABLED=true`. Legacy `SIEM_ADAPTER=http` remains for direct HTTP adapters without MCP.

## Implementation

- MCP client: [`projects/egregore/cys_core/integrations/siem_mcp_client.py`](../../projects/egregore/cys_core/integrations/siem_mcp_client.py)
- LangChain tools: [`projects/egregore/cys_core/registry/siem_tools.py`](../../projects/egregore/cys_core/registry/siem_tools.py)
- Tool gateway adapter: [`projects/egregore/interfaces/gateways/tool/adapters/siem_mcp.py`](../../projects/egregore/interfaces/gateways/tool/adapters/siem_mcp.py)
- SOC skill: [`projects/egregore/agents/skills/siem-investigation/SKILL.md`](../../projects/egregore/agents/skills/siem-investigation/SKILL.md)

## Curated tools (SOC)

| Tool | Purpose |
|------|---------|
| `investigate_incident` | Primary triage by incident ID |
| `list_incidents` | Incident queue |
| `search_events` | PDQL event search |
| `get_event_by_uuid` | Event drill-down |
| `list_aggregated_events` | Timeline aggregates |
| `lookup_assets_by_ip` | Asset enrichment |
| `export_table_list` | IOC / table export |
| `search_user_actions` | Audit trail |
| `search_api_docs` | API doc escape hatch |

## Verification

See [`projects/egregore/docs/trace-audit-checklist.md`](../../projects/egregore/docs/trace-audit-checklist.md) — SIEM MCP section.

Smoke: `projects/maxpatrol-siem-mcp/scripts/smoke_mcp.sh`

## References

- [deploy/ports.md](../../deploy/ports.md) — port **8094**
- [maxpatrol-siem-mcp README](../../projects/maxpatrol-siem-mcp/README.md)
- [egregore-veil-mcp.md](egregore-veil-mcp.md) — parallel pattern
