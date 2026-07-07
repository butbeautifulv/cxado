# egregore ↔ Tenable Nessus MCP integration

**Status:** wired (read-only Nessus inventory tools via `nessus_mcp_client`).

## Goal

Allow egregore hunter/network agents to query **Nessus scan inventory** via **tenable-mcp** with Langfuse `tool.invoke` tracing.

## Prerequisites

```bash
make bootstrap
# Configure deploy/.secrets/tenable-mcp.env (NESSUS_BASE_URL, credentials)
./scripts/k8s/k3s-deploy-tenable-mcp.sh
# Then upgrade egregore (nessus.mcpEnabled in values-egregore-offline.yaml)
```

For local dev without k8s:

```bash
# Configure projects/tenable-mcp/.env
make cxado-up-tenable-mcp
make -C projects/egregore dev
```

## Environment

In `projects/egregore/.env`:

```env
NESSUS_MCP_ENABLED=true
NESSUS_MCP_URL=http://localhost:8095/mcp
NESSUS_MCP_TIMEOUT=180
```

## Implementation

- MCP client: [`projects/egregore/cys_core/integrations/nessus_mcp_client.py`](../../projects/egregore/cys_core/integrations/nessus_mcp_client.py)
- LangChain tools: [`projects/egregore/cys_core/registry/nessus_tools.py`](../../projects/egregore/cys_core/registry/nessus_tools.py)
- Tool provider: [`projects/egregore/cys_core/application/tools/providers/nessus.py`](../../projects/egregore/cys_core/application/tools/providers/nessus.py)
- Tool gateway adapter: [`projects/egregore/cys_core/infrastructure/tools/adapters/nessus_mcp.py`](../../projects/egregore/cys_core/infrastructure/tools/adapters/nessus_mcp.py)
- Skill: [`projects/egregore/agents/skills/vulnerability-inventory/SKILL.md`](../../projects/egregore/agents/skills/vulnerability-inventory/SKILL.md)

## Curated tools (hunter / network)

| Tool | Purpose |
|------|---------|
| `list_scans` | List Nessus scans |
| `get_scan_status` | Scan completion status |
| `wait_for_scan` | Poll until scan completes |
| `sync_scan_inventory` | Export + upsert local CMDB |
| `lookup_asset_by_ip` | Asset by IP |
| `search_inventory` | Filter inventory |
| `get_asset_vuln_summary` | Severity aggregates |
| `get_asset_findings` | Plugin-level findings |
| `list_high_risk_assets` | Critical/high hosts |
| `search_api_docs` | API doc escape hatch |

## Verification

Smoke: `projects/tenable-mcp/scripts/smoke_mcp.sh` or `make cxado-smoke-tenable-mcp`

## References

- [deploy/ports.md](../../deploy/ports.md) — port **8095**
- [tenable-mcp README](../../projects/tenable-mcp/README.md)
- [egregore-siem-mcp.md](egregore-siem-mcp.md) — parallel pattern
