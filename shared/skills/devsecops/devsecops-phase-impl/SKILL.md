---
name: devsecops-phase-impl
description: >-
  Implements DevSecOps CI/CD sub-phases (P0–F3) with minimal-diff PR rules.
  Use when adding pipeline jobs, security gates, or phase documentation
  to this template repository.
---

# DevSecOps phase implementation

## Rules (strict)

- **One sub-phase = one PR**
- **≤ 5 files** per PR
- Typical: +1 job, +1 CI include, +1 policy section, +1 `docs/phases/*.md`
- **warn → block** in separate micro-PR after burn-in

## Order

P0 → A1–A2 → B1–B5 → C1–C4 → D1–D3 → E1–E4 → F1–F3

## File locations

| Platform | Main | Jobs |
|----------|------|------|
| GitLab | `templates/gitlab/.gitlab-ci.yml` | `templates/gitlab/jobs/` |
| GitHub | `templates/github/workflows/security-gates.yml` | `templates/github/workflows/jobs/` |

Contract: `config/security-gate-policy.yaml`

## Add a security job

1. Copy conventions from sibling job (e.g. `sast.yml`)
2. Add policy section to `security-gate-policy.yaml`
3. Include in platform main workflow
4. Mirror GitLab ↔ GitHub
5. Write `docs/phases/{ID}.md` with DAF practice IDs
6. Update `docs/03-security-controls.md` matrix row

## Out of CI

- WAF, RASP (F2) — runbook only
- ASTO — SARIF upload, not scanner
- Fuzzing/sanitizers — QA, optional
- IAST — F1 optional, don't block CI by default

## Phase doc template

```markdown
# {ID}: {Title}
## Goal
## DAF / JCSF practices
## Files changed
## Gate mode (warn/block)
## Verification
```

Full phase table: [reference.md](reference.md)

Start with skill `devsecops-template` for repo overview.
