# DAF subdomains (synthesized)

## Technology (T-*)

| ID | Subdomain |
|----|-----------|
| T-ADI-DEP | Third-party components control |
| T-ADI-ART | Artifact management |
| T-DEV-COMP | Developer workstation protection |
| T-DEV-SM | Secrets (dev) |
| T-DEV-BLD | Build environment |
| T-DEV-SCM | SCM protection |
| T-DEV-SRC | Source change control |
| T-DEV-CICD | CI/CD protection |
| T-CODE-SPC | Custom/outsource dev security |
| T-CODE-SST | SAST |
| T-CODE-SC | SCA |
| T-CODE-IMG | Container images |
| T-CODE-SECDN | Secret detection in code |
| T-CODE-DOCKERFS | Dockerfile |
| T-PREPROD-DAST | DAST preprod |
| T-PREPROD-PENTEST | Pentest preprod |
| T-PREPROD-VULN | Infra vuln scan preprod |
| T-PREPROD-SECTEST | Security functional tests |
| T-PREPROD-MANSEC | IaC / manifests |
| T-PROD-SM | Secrets prod |
| T-PROD-DAST | DAST prod |
| T-PROD-PENTEST | Pentest prod |
| T-PROD-ACCESS | IaC / infra access |
| T-PROD-NETWORK | L4–L7 network |
| T-PROD-RUN | Runtime policies |
| T-PROD-VULN | Vuln scan prod |
| T-PROD-EVENTS | SIEM / security events |

## Process (P-*)

Full P-* subdomains: `devsecops-governance` skill, [07-governance-and-docs.md](../../docs/07-governance-and-docs.md), [daf-kirillamida.md](../../docs/references/daf-kirillamida.md).

## miniRoadmap hints (from xlsx)

Typical sequencing:
- Q1–Q2: Build hardening, SCM hardening, RBAC
- Q3: SAST, SCA, secret detection rollout
- Q3–Q4: Container scan + runtime for all teams
- Year+1: Vault, DAST, XDR on workstations

Full sheet: `--sheet "miniRoadmap"`
