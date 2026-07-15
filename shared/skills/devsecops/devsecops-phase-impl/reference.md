# Phase implementation reference

Execution plan: `.cursor/plans/devsecops-execution.plan.md`.

## Progressive profiles (`templates/profiles/`)

| Profile | Includes |
|---------|----------|
| `minimal` | A2 only (_base) |
| `shift-left` | A2 + B1–B6 |
| `supply-chain` | + C1–C4 |
| `full` | + D1–D3, F jobs, K8s hooks |

Adopt: `scripts/adopt.sh --profile shift-left --platform gitlab --target /path`

## CF wave (Cursor fixation)

- `AGENTS.md`, `.cursor/rules/phase-impl.mdc`, `templates-ci.mdc`
- Skills synced with execution plan

## Policy keys (`security-gate-policy.yaml`)

| Section | Phase | Default mode |
|---------|-------|--------------|
| secrets | B1 | warn |
| sast | B2 | block |
| sca | B3 | block |
| iac | B4 | block |
| dockerfile | B5 | warn → block |
| linters | B6 | warn |
| sbom | C1 | artifact |
| container | C2 | block |
| dast | D1 | warn/scheduled |
| sec_tests | D2 | warn |

## Gate script

```bash
python scripts/gate-check.py --control sast --report results.sarif \
  --policy config/security-gate-policy.yaml
```

## Example B2 PR (5 files max)

1. `templates/gitlab/jobs/sast.yml`
2. `templates/gitlab/.gitlab-ci.yml` (include)
3. `templates/github/workflows/jobs/sast.yml`
4. `templates/github/workflows/security-gates.yml`
5. `docs/phases/B2-sast.md`

## Verification checklist

- [ ] MR pipeline runs job on changed paths
- [ ] SARIF artifact uploaded
- [ ] `gate-check.py` exits 1 on High finding when mode=block
- [ ] GitHub mirror behaves same as GitLab
- [ ] `docs/03-security-controls.md` row updated
