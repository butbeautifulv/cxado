# cxado — Agent index

Meta-repo umbrella. Load project-specific rules from each submodule:

| Project | Path | Agent docs |
|---------|------|------------|
| Veil | `projects/veil/` | [AGENTS.md](projects/veil/AGENTS.md) — knowledge layer |
| Veneno | `projects/veneno/` | [AGENTS.md](projects/veneno/AGENTS.md) — pentest execution |
| Egregore | `projects/egregore/` | [AGENTS.md](projects/egregore/AGENTS.md) |
| Fabrica | `projects/fabrica/` | [AGENTS.md](projects/fabrica/AGENTS.md) |
| ASOC API | `projects/asoc-api/` | `.cursor/rules/` in repo |

## Shared hubs

- `make bootstrap` — submodules + `refs-link` + `rules-link` + `skills-link` + `skills-install`
- `make rules-link` — symlink `shared/agent-rules/core/` into project rules dirs
- `make skills-link` — symlink `shared/skills/devsecops/` into fabrica `.agents/skills/`
- [docs/ecosystem-map.md](docs/ecosystem-map.md) — DRY rules/skills layers, projects, data flows
- [docs/integration/egregore-veil-mcp.md](docs/integration/egregore-veil-mcp.md) — planned Veil MCP wiring (stub)
