---
name: devsecops-daf
description: >-
  DAF DevSecOps Assessment Framework: Kirillamida maturity levels 0–7,
  technology and process subdomains, practice IDs, target-level algorithm.
  Use for control mapping, phase docs, or GOST/DAF traceability.
---

# DAF (DevSecOps Assessment Framework)

Sources: `docs/references/daf/DAF_public_RU.md`, extracts in `docs/references/extracts/daf/`.

Canonical: [daf-kirillamida.md](../../docs/references/daf-kirillamida.md) (levels 0–7, algorithm, subdomains). Roadmap: [05-maturity-roadmap.md](../../docs/05-maturity-roadmap.md).

## Practice ID format

`{T|P}-{DOMAIN}-{SUB}-{level}-{n}`

Examples: `T-CODE-SST-2-1`, `P-DEFECT-CNS-2-1`, `T-DEV-CICD-1-3`

## Lookup

For extract/re-grep commands see `devsecops-reference-lookup`. Quick:

```bash
rg "T-CODE-SST-2-1" docs/references/daf/DAF_public_RU.md
```

## Subdomains

T-* technology table: [reference.md](reference.md). P-* process: `devsecops-governance` skill and [07-governance-and-docs.md](../../docs/07-governance-and-docs.md).

## Map to template

| DAF subdomain | Template |
|---------------|----------|
| T-CODE-SST | B2 sast |
| T-CODE-SC, T-ADI-DEP | B3 sca, C1 sbom |
| T-CODE-SECDN | B1 secrets |
| T-CODE-DOCKERFS | B5 dockerfile |
| T-PREPROD-MANSEC | B4 iac |
| T-CODE-IMG | C2 container-scan |
| T-PREPROD-DAST | D1 dast |
| T-PROD-RUN | E1 admission |
| P-DEFECT-CNS | ASTO / DefectDojo |

Framework crosswalks: `devsecops-gost`, `docs/references/framework-mappings.md`.
