# cys-agi ↔ Veil MCP integration (stub)

**Status:** planned — not wired in either repository yet.

## Goal

Allow cys-agi agents to:

1. **Read** threat context via `veil-mcp` (graph queries, playbook lookup).
2. **Execute** approved tools via `veil-engage` MCP (catalog-only, no raw shell).

## Prerequisites

- cxado meta-repo bootstrapped (`make bootstrap`)
- Veil platform running locally or in lab (see `projects/veil/docs/deploy/`)
- cys-agi runtime configured (`projects/cys-agi/`)

## Environment variables (draft)

| Variable | Service | Purpose |
|----------|---------|---------|
| `VEIL_MCP_URL` | veil-mcp | Graph read MCP endpoint |
| `VEIL_ENGAGE_MCP_URL` | veil-engage | Tool execution MCP endpoint |
| `VEIL_MCP_TOKEN` | both | Auth token when `secure-engage` profile enabled |

## Checklist (future PR in cys-agi)

- [ ] Add MCP client config to cys-agi agent runtime
- [ ] Map veil-mcp tools to cys-agi Skill Gateway (read-only)
- [ ] Map veil-engage tools to execution policy (allowlist)
- [ ] Integration test against Veil smoke stack
- [ ] Document in cys-agi `AGENTS.md`

## References

- [Veil MCP agents](https://github.com/butbeautifulv/veil/blob/main/docs/agents/mcp-agents.md)
- [cys-agi AGENTS.md](https://github.com/butbeautifulv/cys_agi/blob/main/AGENTS.md)
- [cxado ecosystem map](../ecosystem-map.md)
