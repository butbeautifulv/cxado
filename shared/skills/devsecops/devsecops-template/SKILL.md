---
name: devsecops-template
description: >-
  Master skill for the ci-cd_template DevSecOps repository. Use when working
  on docs, CI jobs, security gates, K8s templates, or implementing sub-phases
  P0–F3. Routes to specialized skills and docs/.
---

# DevSecOps CI/CD template (this repo)

Reference repo: GitLab + GitHub CI, K8s runtime, DAF/JCSF/fintech/GOST synthesis.

## Repo map

| Path | Purpose |
|------|---------|
| `docs/00-master-plan.md` | Executive summary, decision log |
| `docs/01-sdlc-process.md` | SDLC zones, roles, trunk/bugfix |
| `docs/02-pipeline-architecture.md` | Stages, gates, SARIF |
| `docs/03-security-controls.md` | Control matrix |
| `docs/04-tooling-catalog.md` | Tools by class |
| `docs/05-maturity-roadmap.md` | Kirillamida, miniRoadmap, phases |
| `docs/phases/` | One markdown per sub-phase |
| `config/security-gate-policy.yaml` | Shared gate contract |
| `templates/gitlab/` | GitLab CI jobs |
| `templates/github/workflows/` | GitHub Actions jobs |
| `templates/k8s/` | Admission, network, runtime |
| `templates/profiles/` | Progressive adoption (minimal → full) |
| `scripts/adopt.sh` | Copy phases into target repo |
| `scripts/gate-check.py` | SARIF + policy → exit code |
| `.cursor/plans/devsecops-execution.plan.md` | **Active execution plan** |
| `AGENTS.md` | Agent entry point |
| `docs/references/` | DAF, extracts, Secure SDLC, attribution |
| `.agents/skills/` | Canonical agent skills |
| `.cursor/skills/` | Cursor discovery stubs → `.agents/skills/` |

## Specialized skills (use as needed)

| Skill | When |
|-------|------|
| `devsecops-reference-lookup` | Lookup extracts, daf paths |
| `devsecops-secure-sdlc` | 8-stage Plan→Monitor |
| `devsecops-daf` | DAF practices, Kirillamida levels |
| `devsecops-gost` | ГОСТ 56939 ↔ pipeline |
| `devsecops-jcsf` | K8s/container security |
| `devsecops-fintech-sdlc` | Fintech swimlane, MR gates |
| `devsecops-tooling` | Tool selection by class |
| `devsecops-governance` | DSO documents, roles, ASTO |
| `devsecops-phase-impl` | Add jobs/phases (≤5 files/PR) |
| `devsecops-mlsecops` | ML/AI optional appendix |

## Hard rules

See [AGENTS.md](../../AGENTS.md) § Rules and `.cursor/rules/phase-impl.mdc`.

## Phase order

CF → G0 (profiles + adopt.sh) → V0 → H-CORE → H-P0…F3 → AI* → R

Progressive profiles in `templates/profiles/`: `minimal` | `shift-left` | `supply-chain` | `full`

Details: [reference.md](reference.md)
