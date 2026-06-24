# Architecture Decision Records (cxado)

| ADR | Status | Summary |
|-----|--------|---------|
| [cxado-architecture.md](cxado-architecture.md) | accepted | Meta-repo umbrella, domains, hubs, patterns |

## MCP sync

This folder mirrors the ADR stored in **codebase-memory-mcp** for agent sessions.

Agent dev tooling (index, Serena, Context7): [agents/cursor-mcp-tooling.md](../agents/cursor-mcp-tooling.md).

- Read in chat: `manage_adr(mode='get', project='home-bbv-Desktop-cys_framework')`
- Update MCP after editing the markdown: `manage_adr(mode='update', content='...')`
- Re-index after large refactors: `index_repository(repo_path='/path/to/cys_framework')`
