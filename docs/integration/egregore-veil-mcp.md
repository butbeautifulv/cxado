# egregore ↔ Veil MCP integration

**Status:** wired (read-only graph + playbook tools via `veil_mcp_client`).

## Goal

Allow egregore agents to **read** threat context via **veil-mcp** (graph queries, playbook lookup) with Langfuse `tool.invoke` tracing.

## Prerequisites

```bash
make bootstrap
make cxado-up-veil
make -C projects/egregore dev
```

## Environment

In `projects/egregore/.env`:

```env
VEIL_MCP_ENABLED=true
VEIL_MCP_URL=http://localhost:8091/mcp
VEIL_MCP_TIMEOUT=30
```

When Veil secure profile is enabled, set `VEIL_MCP_TOKEN` (or Keycloak bearer) per [veil auth docs](../../projects/veil/docs/deploy/auth-keycloak.md).

## Implementation

- MCP client: [`projects/egregore/cys_core/integrations/veil_mcp_client.py`](../../projects/egregore/cys_core/integrations/veil_mcp_client.py)
- LangChain tools: [`projects/egregore/cys_core/registry/veil_tools.py`](../../projects/egregore/cys_core/registry/veil_tools.py)
- Tool provider metadata: [`projects/egregore/cys_core/application/tools/providers/veil.py`](../../projects/egregore/cys_core/application/tools/providers/veil.py)
- Tool gateway adapter: [`projects/egregore/interfaces/gateways/tool/adapters/veil_mcp.py`](../../projects/egregore/interfaces/gateways/tool/adapters/veil_mcp.py)
- Skill: [`projects/egregore/agents/skills/veil-knowledge/SKILL.md`](../../projects/egregore/agents/skills/veil-knowledge/SKILL.md)

`enrich_ioc` delegates to `ti_search_in_category` when `VEIL_MCP_ENABLED=true`.

## Curated tools

| Tool | Purpose |
|------|---------|
| `ti_search_in_category` | Primary IOC/CVE/actor graph search |
| `ti_get_node` / `ti_neighbors` | Graph drill-down |
| `ti_list_categories` / `ti_list_kinds_in_category` / `ti_nodes_by_category` | Graph navigation |
| `ti_health` | Neo4j connectivity check |
| `playbook_search` | Procedure playbook lookup |
| `playbook_get` / `playbook_procedure` | Full playbook content |
| `playbook_for_technique` | MITRE technique → playbooks |
| `playbook_framework` | Navigator layer / coverage |
| `playbook_subdomains` / `playbook_ontology_subdomains` | Playbook index metadata |

## Personas

Worker personas with Veil tools load `veil-knowledge` skill: intel, soc, hunter, dfir, network, identity, cloud, compliance, consultant, purple, research.

## Verification

See [`projects/egregore/docs/trace-audit-checklist.md`](../../projects/egregore/docs/trace-audit-checklist.md) — Veil MCP section.

Smoke: `projects/egregore/scripts/smoke_veil_mcp.sh` (or `make cxado-smoke-veil-mcp`)

## Veneno (execution)

Pentest execution via **veneno-mcp** remains a separate integration — see veneno deploy docs.

## References

- [deploy/ports.md](../../deploy/ports.md) — port **8091**
- [cxado default stack](../deploy/cxado-default-stack.md)
- [veil AGENTS.md](../../projects/veil/AGENTS.md)
- [egregore-siem-mcp.md](egregore-siem-mcp.md) — parallel pattern
