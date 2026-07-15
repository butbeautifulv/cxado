---
name: devsecops-governance
description: >-
  DSO governance: required org documents from DAF xlsx, P-domain processes,
  roles RACI, Security Champions, ASTO defect management. Use for
  07-governance-and-docs.md or organizational rollout.
---

# DevSecOps governance (DAF)

Source: `DAF_public_RU.xlsx` sheet `Документы для процессов DSO`

Repo: `docs/07-governance-and-docs.md`.

## Required documents (minimum)

| # | Document |
|---|----------|
| 1 | Положение по безопасной разработке ПО |
| 2 | Регламент процесса безопасной разработки |
| 3 | Регламент управления уязвимостями (ASTO) |
| 4 | Стандарты конфигурации приложений |
| 5 | Стандарты конфигурации инфраструктуры |
| 6 | Методика threat modeling |

## Process subdomains (P-*)

| ID | Focus |
|----|-------|
| P-EDU-AWR / P-EDU-KB | Training, wiki |
| P-REQ-TM / P-REQ-RD / P-REQ-CR | TM, requirements, compliance |
| P-REQ-STDR-App / P-REQ-STDR-Infr | App & infra baselines |
| P-DEFECT-MNG / P-DEFECT-CNS | Triage SLA, ASTO |
| P-MET-SET / P-MET-EX | KPIs |
| P-ROLE-SC / P-ROLE-RESP | SecChamp, RACI |

## RACI in CI/CD

| Role | RACI |
|------|------|
| Developer | R: fix findings |
| SecChamp | A: triage, exceptions |
| AppSec | C: scanner policies |
| DevOps | R: pipeline |
| QA | R: sec func tests |

## ASTO integration

`P-DEFECT-CNS`: SARIF from pipeline → DefectDojo / Jit / AppSec.Track

Marked SAST report before merge (fintech PDF).

## Audit report template

From xlsx `Документы для процессов DSO`:
- Current processes description
- Strengths / weaknesses
- Recommendations per SDLC stage

FTE planning: sheets `FTE AppSec`, `Расчет FTE DSO`.

Outline: [reference.md](reference.md)
