# cxado ecosystem map

High-level view of projects, shared hubs, and planned integrations.

```mermaid
flowchart TB
  subgraph cxado [cxado meta-repo]
    SKILLS[shared/skills]
    REFS[shared/references]
    subgraph projects [projects]
      VEIL[veil]
      AGI[cys-agi]
      CICD[ci-cd-template]
      ASOC[asoc-api]
    end
  end

  SKILLS -->|make skills-install| CURSOR[Cursor IDE]
  REFS -->|refs symlink| VEIL
  REFS -->|refs symlink| CICD
```

## Projects

| Project | Role | Stack |
|---------|------|-------|
| **veil** | Threat intelligence, engage tools, MCP | Go, Neo4j |
| **cys-agi** | Event-driven multi-agent SOC | Python |
| **ci-cd-template** | DevSecOps CI/CD reference | YAML, scripts |
| **asoc-api** | Scan aggregation → NATS | Go |

## Shared hubs

| Hub | Contents | Not included |
|-----|----------|--------------|
| **cxado-skills** | 13 Cursor dev skills | Veil corpus (754 playbooks), cys-agi runtime skills |
| **cxado-references** | JCSF, DAF, hexstrike, OWASP PDFs | Anthropic Skills upstream (Veil-local) |

## Data flows (planned / partial)

```mermaid
flowchart LR
  SCANNERS[Bandit Trivy ZAP] --> ASOC[asoc-api]
  ASOC -->|NATS findings| AGI[cys-agi]
  VEIL[veil engage] -->|engage.events| ASOC
  CICD[ci-cd-template] -->|adopt.sh| AGI
  CICD -->|adopt.sh| VEIL
```

- **ASOC → cys-agi:** NATS JetStream normalized scan events (not wired in cys-agi yet).
- **Veil engage → ASOC:** engage audit/events export (roadmap).
- **CI/CD template → projects:** `scripts/adopt.sh` copies gates and profiles.

## MCP integration (planned)

```mermaid
flowchart LR
  AGI[cys-agi agents] -->|MCP client read| MCP[veil-mcp]
  AGI -->|MCP client exec| ENG[veil-engage]
```

cys-agi can consume Veil graph read and engage tool execution via MCP — **not implemented** in this meta-repo bootstrap. See [integration/cys-agi-veil-mcp.md](integration/cys-agi-veil-mcp.md).

## Clone entrypoint

```bash
git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git
cd cxado && make bootstrap
```
