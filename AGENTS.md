# cxado — Agent index

Meta-repo umbrella. Load project-specific rules from each submodule:

| Project | Path | Agent docs |
|---------|------|------------|
| Veil | `projects/veil/` | [AGENTS.md](projects/veil/AGENTS.md) — knowledge layer |
| Veneno | `projects/veneno/` | [AGENTS.md](projects/veneno/AGENTS.md) — pentest execution |
| Egregore | `projects/egregore/` | [AGENTS.md](projects/egregore/AGENTS.md) |
| Fabrica | `projects/fabrica/` | [AGENTS.md](projects/fabrica/AGENTS.md) |
| Hexenhammer | `projects/hexenhammer/` | [AGENTS.md](projects/hexenhammer/AGENTS.md) — awareness domain |
| ASOC API | `projects/asoc-api/` | `.cursor/rules/` in repo |

**Domains (local / planned):** [Tabula](projects/tabula/README.md) (compliance, fstec module) · fstec/fish repos under `projects/` (not submodules yet)

## Shared hubs

- `make bootstrap` — submodules + `refs-link` + `rules-link` + `skills-link` + `skills-install` + `gui-link`
- `make rules-link` — symlink `shared/agent-rules/core/` into project rules dirs
- `make skills-link` — symlink `shared/skills/devsecops/` into fabrica `.agents/skills/`
- `make gui-link` — symlink `shared/gui` into pilot project `node_modules/@cxado/gui` (Veil)
- [docs/ecosystem-map.md](docs/ecosystem-map.md) — DRY rules/skills layers, projects, data flows
- [docs/integration/egregore-veil-mcp.md](docs/integration/egregore-veil-mcp.md) — planned Veil MCP wiring (stub)
