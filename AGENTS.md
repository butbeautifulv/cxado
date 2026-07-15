# cxado — Agent index

Meta-repo umbrella. Load project-specific rules from each submodule:

| Project | Path | Agent docs |
|---------|------|------------|
| Veil | `projects/veil/` | [AGENTS.md](projects/veil/AGENTS.md) — knowledge layer |
| Veneno | `projects/veneno/` | [AGENTS.md](projects/veneno/AGENTS.md) — pentest execution |
| Egregore | `projects/egregore/` (API root + `web_ui/`) | [AGENTS.md](projects/egregore/AGENTS.md) |
| Fabrica | `projects/fabrica/` | [AGENTS.md](projects/fabrica/AGENTS.md) |
| Precursor | `projects/precursor/` | MCP adapters (SIEM, Nessus, DefectDojo) — [README](projects/precursor/README.md) |

## Agent tooling

Core rule: [`shared/agent-rules/core/agent-mcp-tooling.mdc`](shared/agent-rules/core/agent-mcp-tooling.mdc) (via meta [`.cursor/rules/`](.cursor/rules/) when using `cxado.code-workspace`).

| Task | Tool |
|------|------|
| Third-party library docs (React, Next, shadcn, Tailwind, cloud APIs) | **Context7** (`resolve-library-id`, `query-docs`) |
| Internal code: where is X, architecture | **Scoped Grep / Read / Glob** — limit to `projects/<submodule>/` |
| UI smoke test | **cursor-ide-browser** |
| Architecture decisions | [docs/adr/](docs/adr/), [docs/ecosystem-map.md](docs/ecosystem-map.md) |

Full routing: [docs/agents/cursor-mcp-tooling.md](docs/agents/cursor-mcp-tooling.md)

## Legacy paths

| Legacy | Notes |
|--------|-------|
| `cys-agi` (repo) | `projects/egregore` |
| `ci-cd-template` | `projects/fabrica` |
| hexenhammer / tabula / fstec / asoc-api | **Out of scope** — standalone on `~/Desktop/` |
| cxado-agent-rules / cxado-skills / cxado-references / cxado-gui | merged into `shared/*` in cxado meta-repo |
| codebase-memory-mcp / `.codebase-memory/` | **removed** (2026-07) — use scoped grep + ADR docs |

## Shared hubs

- `make bootstrap` — submodules + `skills-link` + `skills-install` + `gui-link` + legacy symlink cleanup
- Core agent rules — `shared/agent-rules/core/` + [`.cursor/rules/`](.cursor/rules/) at cxado root (no per-project symlinks)
- `make skills-link` — symlink `shared/skills/devsecops/` into fabrica `.agents/skills/`
- `make gui-link` — symlink `shared/gui` into pilot project `node_modules/@cxado/gui` (Veil)
- `make auth-broker-test` — run tests for `shared/go/auth-broker`
- [docs/ecosystem-map.md](docs/ecosystem-map.md) — DRY rules/skills layers, projects, data flows
- [docs/adr/cxado-architecture.md](docs/adr/cxado-architecture.md) — architecture ADR
- [docs/agents/cursor-mcp-tooling.md](docs/agents/cursor-mcp-tooling.md) — **Context7** + scoped search
- [docs/integration/egregore-veil-mcp.md](docs/integration/egregore-veil-mcp.md) — egregore ↔ veil-mcp (wired, read-only graph tools)
- [docs/integration/egregore-siem-mcp.md](docs/integration/egregore-siem-mcp.md) — egregore ↔ maxpatrol-siem-mcp (SOC SIEM tools)
- [docs/integration/egregore-tenable-mcp.md](docs/integration/egregore-tenable-mcp.md) — egregore ↔ tenable-mcp (Nessus vulnerability inventory)
- [docs/observability/README.md](docs/observability/README.md) — k3s offline observability, validation gate, worker telemetry
- [docs/deploy/k3s-offline-baseline.md](docs/deploy/k3s-offline-baseline.md) — offline lab k3s deploy baseline
- **Build + deploy (canonical, P30)** — Kaniko in-cluster build → Nexus → helm upgrade:
  - [docs/deploy/nexus-egregore-loop.md](docs/deploy/nexus-egregore-loop.md) — `./scripts/k8s/cxado-nexus-deploy.sh --build --tag "$TAG"`
  - [docs/deploy/nexus-veil-loop.md](docs/deploy/nexus-veil-loop.md) — `./scripts/k8s/cxado-nexus-deploy-veil.sh --build --tag "$TAG"`
  - `scripts/k8s/k3s-offline-bundle-infra.sh` — infra tar import (nats/neo4j); app images via Nexus loops
- **Git remotes:** `origin` = GitHub (default). Corp GitLab: `./scripts/gitlab/sync-monorepo-to-gitlab.sh` only. Normalize: `./scripts/gitlab/setup-github-remotes.sh`
- [deploy/k8s/defectdojo-offline/README.md](deploy/k8s/defectdojo-offline/README.md) — DefectDojo in-cluster ASPM (`:30808`)
