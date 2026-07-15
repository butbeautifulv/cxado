---
name: devsecops-gost
description: >-
  Maps ГОСТ Р 56939-2024 requirements to DAF practices and CI/CD pipeline
  controls. Use for compliance audits, release gates, or regulatory traceability.
---

# ГОСТ Р 56939-2024 compliance

Source: `DAF_public_RU.xlsx` sheet `ГОСТ56939_mapping` (561 rows).

Canonical mapping: [08-compliance-gost-56939.md](../../docs/08-compliance-gost-56939.md). Full 5.1–5.25 list: [fintech supplement §ГОСТ](../../docs/references/supplements/Типовой_процесс_безопасной_разработки_для_финтеха.md#соответствие-гост-р-56939-2024).

## Agent actions

1. For pipeline-relevant sections (5.10–5.21) read `08-compliance-gost-56939.md` §Pipeline.
2. Link each GOST requirement to SARIF/SBOM artifact or phase checklist.
3. For extract rows use `devsecops-reference-lookup` (sheet `ГОСТ56939_mapping`).

## Audit workflow

1. Fill maturity in DAF xlsx `Кирилламида` / `Результаты аудита`
2. For each GOST requirement, link pipeline artifact (SARIF, SBOM, checklist)
3. Cross-check SAMM/DSOMM via `SAMM_mapping`, `DSOMM_mapping` sheets

Fintech: DAF `Практики` sheet has **ПЗ ЦБ** column for regulated orgs.

More rows: [reference.md](reference.md)
