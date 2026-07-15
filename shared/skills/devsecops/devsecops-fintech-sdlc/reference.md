# Fintech roles & artifacts

## Roles

| Role | CI/CD responsibility |
|------|---------------------|
| Developer | Code, unit tests, fix findings |
| SecChamp | SAST/SCA triage, taint analysis, MR security review |
| AppSec analyst | Requirements, DAST scripts, pentest |
| QA | Func tests, fuzzing, sec func tests |
| DevOps | Pipeline templates, deploy, registry |
| PO / PM | Prioritization, risk acceptance |
| Ops engineer | Prod deploy, WAF, K8s |
| Security controller | Prod policies, ASTO, IRM |

## Artifacts by stage

| Stage | Artifacts |
|-------|-----------|
| Design | Requirements, architecture, attack surface |
| MR | SARIF, linter reports, review comments |
| QA | Fuzz seeds, coverage, sanitizer logs |
| Build | SBOM, image, scans, **marked SAST report** |
| Release | Signed artifacts, pentest report |
| Prod | OBOM/SBOM monitor, SIEM, RASP/WAF events |

## Build pipeline (PDF)

- Centralized pipeline templating
- SBOM mandatory
- Signed artifacts (optional on diagram)
- SCA gate in CD: block if dependencies worsened

## Not in base CI template

Fuzzing, concolic, sanitizers → QA zone, optional jobs.
Taint analysis → design phase, SecChamp tooling.
ASTO → process integration (SARIF upload), not a scan job.
