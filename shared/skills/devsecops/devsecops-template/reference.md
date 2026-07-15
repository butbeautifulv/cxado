# Phase reference (P0–F3)

| Phase | Files | Gate focus |
|-------|-------|------------|
| P0 | docs only | — |
| A1 | SCM hardening | branch protection |
| A2 | CI skeleton | stages, cache, MR rules |
| B1 | secret-scan | warn → block |
| B2 | sast | SARIF, block High+ |
| B3 | sca | dependency review |
| B4 | iac-scan | tf/k8s/helm |
| B5 | dockerfile-lint | hadolint/checkov |
| C1 | sbom | CycloneDX artifact |
| C2 | container-scan | post-build CVE |
| C3 | registry policy | pull-only workers |
| C4 | sign | cosign optional |
| D1 | dast | preprod ZAP |
| D2 | sec-func-tests | auth/headers harness |
| D3 | pentest | release checklist |
| E1 | k8s/admission | Kyverno/OPA |
| E2 | k8s/network | NetworkPolicy |
| E3 | k8s/runtime | Falco doc |
| E4 | siem rules | correlation stub |
| F1 | iast-preprod | optional inject |
| F2 | WAF/RASP | runbook only |
| F3 | passive DAST, SBOM verify | advanced |

## Kirillamida target (default)

Start at level **2 Базовый**. See `devsecops-daf` skill.

## Platform mirror

Every GitLab job in `templates/gitlab/jobs/` should have GitHub equivalent in `templates/github/workflows/jobs/`.
