# cxado — Agent index

Meta-repo umbrella. Load project-specific rules from each submodule:

| Project | Path | Agent docs |
|---------|------|------------|
| Veil | `projects/veil/` | [AGENTS.md](projects/veil/AGENTS.md) — knowledge layer |
| Veneno | `projects/veneno/` | [AGENTS.md](projects/veneno/AGENTS.md) — pentest execution |
| Egregore | `projects/egregore/` (API root + `ui/`) | [AGENTS.md](projects/egregore/AGENTS.md) |
| Fabrica | `projects/fabrica/` | [AGENTS.md](projects/fabrica/AGENTS.md) |
| Hexenhammer | `projects/hexenhammer/` | [AGENTS.md](projects/hexenhammer/AGENTS.md) — awareness module 1 (phishing); domain: [docs/domains/awareness.md](docs/domains/awareness.md) |
| Tabula | `projects/tabula/` | [AGENTS.md](projects/tabula/AGENTS.md) — compliance domain (fstec submodule) |
| ASOC API | `projects/asoc-api/` | `.cursor/rules/` in repo |

## MCP-first (mandatory)

Agents **must** use the MCP stack before blind grep loops or API guesses. Core rule: `shared/agent-rules/core/agent-mcp-tooling.mdc` (symlinked via `make rules-link`).

### Exploration ladder (internal code)

Use in order; stop when you have a hit:

1. **codebase-memory** — `search_code` or `trace_path` with **project scope** (see below)
2. **Serena** — `find_symbol` / `find_referencing_symbols` with `relative_path` scoped to the target submodule
3. **Blind grep** — only if MCP returned 0 *and* you noted stale index or MCP failure

| Task | MCP |
|------|-----|
| Architecture / cross-module / "where is X?" | **codebase-memory-mcp** |
| Rename / references / symbols | **Serena** (`initial_instructions` at task start) |
| Library docs (React, Next, shadcn, Tailwind) | **Context7** — third-party only, not internal Python/Go |
| UI smoke test | **cursor-ide-browser** |

### Scoping (avoid references / veil corpus noise)

| Target | codebase-memory | Serena |
|--------|-----------------|--------|
| egregore | `project=home-bbv-Desktop-cys_framework`, `path_filter=projects/egregore` | `relative_path=projects/egregore` |
| veil | `path_filter=projects/veil` | `relative_path=projects/veil` |
| hexenhammer | `path_filter=projects/hexenhammer` | `relative_path=projects/hexenhammer` |
| tabula/fstec | `path_filter=projects/tabula/fstec` | `relative_path=projects/tabula/fstec` |

If `search_code` returns 0 but you expect hits: call `index_status` — index is likely stale. **Do not** run full `index_repository` while another agent has an open egregore branch; re-index **after merge** (`scripts/reindex-post-merge.sh`).

Full routing + pitfalls: [docs/agents/cursor-mcp-tooling.md](docs/agents/cursor-mcp-tooling.md)

## Legacy paths

| Legacy | Canonical path |
|--------|----------------|
| fstec (pre-Tabula) | [projects/tabula/fstec](projects/tabula/fstec) submodule |

## Shared hubs

- `make bootstrap` — submodules + `refs-link` + `rules-link` + `skills-link` + `skills-install` + `gui-link`
- `make rules-link` — symlink `shared/agent-rules/core/` into project rules dirs
- `make skills-link` — symlink `shared/skills/devsecops/` into fabrica `.agents/skills/`
- `make gui-link` — symlink `shared/gui` into pilot project `node_modules/@cxado/gui` (Veil)
- `make auth-broker-test` — run tests for `shared/go/auth-broker`
- [docs/domains/awareness.md](docs/domains/awareness.md) — Awareness domain (testing, training; phishing = module 1)
- [docs/ecosystem-map.md](docs/ecosystem-map.md) — DRY rules/skills layers, projects, data flows
- [docs/adr/cxado-architecture.md](docs/adr/cxado-architecture.md) — architecture ADR (also in codebase-memory-mcp)
- [docs/agents/cursor-mcp-tooling.md](docs/agents/cursor-mcp-tooling.md) — agent MCP stack: **codebase-memory-mcp**, **Serena**, **Context7 (ctx7)**
- [docs/integration/egregore-veil-mcp.md](docs/integration/egregore-veil-mcp.md) — egregore ↔ veil-mcp (wired, read-only graph tools)
- [docs/integration/egregore-siem-mcp.md](docs/integration/egregore-siem-mcp.md) — egregore ↔ maxpatrol-siem-mcp (SOC SIEM tools)
- [docs/integration/egregore-tenable-mcp.md](docs/integration/egregore-tenable-mcp.md) — egregore ↔ tenable-mcp (Nessus vulnerability inventory)
- [docs/observability/README.md](docs/observability/README.md) — k3s offline observability, validation gate, worker telemetry
- [docs/deploy/k3s-offline-baseline.md](docs/deploy/k3s-offline-baseline.md) — P30 offline k3s deploy baseline
- **Build + deploy (canonical, P30)** — Kaniko in-cluster build → push to Nexus → helm upgrade. No `docker save`/tar import for app images.
  - [docs/deploy/nexus-egregore-loop.md](docs/deploy/nexus-egregore-loop.md) — egregore api+worker+ui: `./scripts/k8s/cxado-nexus-deploy.sh --build --tag "$TAG"`
  - [docs/deploy/nexus-veil-loop.md](docs/deploy/nexus-veil-loop.md) — veil-api+veil-mcp: `./scripts/k8s/cxado-nexus-deploy-veil.sh --build --tag "$TAG"`
  - `scripts/k8s/k3s-offline-bundle-*.sh` / `k3s-distribute-offline-tag.sh` are DEPRECATED fallback only — do not use for a normal deploy loop.
- [deploy/k8s/defectdojo-offline/README.md](deploy/k8s/defectdojo-offline/README.md) — DefectDojo in-cluster ASPM (`:30808`)
