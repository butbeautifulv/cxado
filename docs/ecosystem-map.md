# cxado ecosystem map

High-level view of projects, shared hubs, and planned integrations.

```mermaid
flowchart TB
  subgraph cxado [cxado meta-repo]
    RULES[shared/agent-rules]
    SKILLS[shared/skills]
    REFS[shared/references]
    CTR[shared/contracts]
    subgraph projects [projects]
      VEIL[veil knowledge]
      VENENO[veneno pentest]
      AGI[egregore]
      CICD[fabrica]
      ASOC[asoc-api]
    end
  end

  RULES -->|make rules-link| VEIL
  RULES -->|make rules-link| VENENO
  RULES -->|make rules-link| AGI
  SKILLS -->|make skills-install| CURSOR[Cursor IDE]
  SKILLS -->|make skills-link| FAB[fabrica skills]
  REFS -->|refs symlink| VEIL
  REFS -->|refs symlink| CICD
  REFS -->|refs symlink| AGI
```

## DRY agent rules & skills

```mermaid
flowchart TB
  subgraph hub [cxado hubs]
    AR[agent-rules/core]
    SK[skills/agent]
  end
  subgraph veil [veil overlay]
    V1[veil-agent-workflow]
    V2[security-frameworks]
  end
  subgraph agi [egregore overlay]
    A1[project-workflow]
    A2[project-security]
    A3[agents/skills thin overlay]
  end
  AR -->|core-*.mdc symlinks| veil
  AR -->|core-*.mdc symlinks| agi
  SK -->|make skills-install| CURSOR[Cursor IDE]
  SK -->|extends| A3
```

| Layer | Location | Runtime? |
|-------|----------|----------|
| **Core rules** | `shared/agent-rules/core/*.mdc` | No — symlinked into projects |
| **Project overlay** | 1–4 `.mdc` per repo | No |
| **Generic agent skills** | `shared/skills/agent/*` | No — Cursor dev |
| **Product skills** | `egregore/agents/skills/` | Yes — Skill Gateway |

## Projects

| Project | Role | Stack |
|---------|------|-------|
| **veil** | TI graph, ingest, veil-api, veil-mcp | Go, Neo4j |
| **veneno** | Pentest execution, veneno-api, veneno-mcp | Go |
| **egregore** | Event-driven multi-agent SOC | Python |
| **fabrica** | DevSecOps CI/CD reference | YAML, scripts |
| **asoc-api** | Scan aggregation → NATS | Go |

## Shared hubs

| Hub | Contents | Not included |
|-----|----------|--------------|
| **cxado-agent-rules** | 6 core Cursor rules (karpathy, critic, branches, kaizen, docs, workflow) | Project overlays |
| **cxado-skills** | 12 devsecops + veil + 5 agent/* generic skills | Veil corpus (754 playbooks), egregore product runtime |
| **cxado-references** | JCSF, DAF, OWASP cheat sheets, hexstrike extracts | Anthropic Skills upstream (Veil-local) |

## Agent rules & skills (by project)

Core rules linked via `make rules-link`; see [Veil cursor-rules-index](projects/veil/docs/agents/cursor-rules-index.md).

| Project | Core rules | Project overlay | Product / runtime skills |
|---------|------------|-----------------|--------------------------|
| **veil** | `core-*.mdc` symlinks | 4 `veil-*.mdc` (knowledge) | `corpus/` (754 playbooks) |
| **veneno** | `core-*.mdc` symlinks | 2 `project-*.mdc` | tool catalog runtime |
| **egregore** | `core-*.mdc` symlinks | 2 `project-*.mdc` | `agents/skills/` (Skill Gateway) |
| **fabrica** | `core-*.mdc` symlinks | `project-workflow.mdc` + `.cursor/rules/` | `skills-link` devsecops |
| **fish** (external) | copy (pre-DRY) | `.agents/rules/fish-*.mdc` | — |

- **cxado-skills** (`make skills-install` + `make skills-link`): devsecops symlinks in fabrica; agent/* via global install — **not** egregore runtime overlays.
- **egregore** OWASP: `shared/references/owasp/` via `refs-link`; sync pointers via `scripts/generate_owasp_skills.py`.
- **Wire contracts:** `shared/contracts/` — `make test-contracts`.

## Data flows (planned / partial)

```mermaid
flowchart LR
  SCANNERS[Bandit Trivy ZAP] --> ASOC[asoc-api]
  ASOC -->|NATS findings| AGI[egregore]
  VENENO[veneno] -->|engage.events| VEIL[veil ingest]
  CICD[fabrica] -->|adopt.sh| AGI
  CICD -->|adopt.sh| VEIL
```

- **ASOC → egregore:** NATS JetStream normalized scan events (not wired in egregore yet).
- **Veneno → veil:** engage.events ingest bridge (wired).
- **Fabrica → projects:** `scripts/adopt.sh` copies gates and profiles.

## MCP integration (planned)

```mermaid
flowchart LR
  AGI[egregore agents] -->|MCP client read| MCP[veil-mcp]
  AGI -->|MCP client exec| VEN[veneno-mcp]
```

egregore can consume Veil graph read and veneno tool execution via MCP — **not implemented** in this meta-repo bootstrap. See [integration/egregore-veil-mcp.md](integration/egregore-veil-mcp.md).

## Clone entrypoint

```bash
git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git
cd cxado && make bootstrap
```
