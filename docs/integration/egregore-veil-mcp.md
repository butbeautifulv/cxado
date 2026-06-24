# egregore ↔ Veil / Veneno MCP integration (stub)

**Status:** planned — not wired in either repository yet.

## Goal

Allow egregore agents to:

1. **Read** threat context via **veil-mcp** (graph queries, playbook lookup) — `projects/veil`.
2. **Execute** approved tools via **veneno-mcp** (catalog-only) — `projects/veneno`.

## Prerequisites

- cxado meta-repo bootstrapped (`make bootstrap`)
- Veil knowledge stack + Veneno pentest stack running (see deploy docs)
- egregore runtime configured

## Environment variables (draft)

| Variable | Service | Purpose |
|----------|---------|---------|
| `VEIL_MCP_URL` | veil-mcp | Graph read MCP endpoint |
| `VENENO_MCP_URL` | veneno-mcp | Tool execution MCP endpoint |
| `VEIL_MCP_TOKEN` | veil | Auth token when secure profile enabled |
| `VENENO_MCP_TOKEN` | veneno | Auth token when secure profile enabled |

## Checklist (future PR in egregore)

- [ ] Add MCP client config to egregore agent runtime
- [ ] Map veil-mcp tools to Skill Gateway (read-only)
- [ ] Map veneno-mcp tools to execution policy (allowlist)
- [ ] Integration test against combined smoke stack
- [ ] Document in egregore `AGENTS.md`

## References

- [veil AGENTS.md](https://github.com/butbeautifulv/veil/blob/main/AGENTS.md)
- [veneno AGENTS.md](https://github.com/butbeautifulv/veneno/blob/main/AGENTS.md)
- [cxado ecosystem map](../ecosystem-map.md)
