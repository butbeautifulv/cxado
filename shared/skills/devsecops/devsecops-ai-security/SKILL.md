---
name: devsecops-ai-security
description: >-
  Optional AI/ML security from Cisco AI Defense and DAF MLSecOps: skill scanning,
  MCP security, AI BOM, model provenance. Use for AI1/ML1 phases, not standard CI/CD.
---

# AI security (optional)

Sources: `docs/references/cisco-ai-defense.md`, `docs/11-ai-security-appendix.md`, `docs/10-mlsecops-appendix.md`

## When to use

- Repo contains `.cursor/skills/`, `.agents/skills/`, MCP configs, or ML models
- Adopt profile: **`ai-ml`** — not included in `shift-left` / `full` by default

## Tools

| Tool | Scan target |
|------|-------------|
| skill-scanner | Agent SKILL.md files |
| mcp-scanner | MCP server definitions |
| aibom | AI dependencies |
| pickle-scan | Python pickle in ML artifacts |

## CI jobs (profile ai-ml)

| Job | Phase | Gate |
|-----|-------|------|
| `skill-scanner.yml` | AI1 | warn |
| `mcp-scan.yml` | AI1 | warn |
| `aibom.yml` | AI2 | warn |
| `pickle-scan.yml` | AI2 | warn |

Fallback scanner: `scripts/ai-ml-scan.py`

Phase docs: `docs/phases/AI1-skill-scan.md` … `AI3-rag-runtime.md`

## MLSecOps overlap

ML data gates: `devsecops-mlsecops` skill — `T-MLDATA-DT-4-*`

## PR scope

Same rules: ≤5 files, warn-only default for AI1–AI2.
