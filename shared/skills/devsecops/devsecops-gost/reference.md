# GOST ↔ pipeline traceability

## MR / build controls

| Control | GOST sections |
|---------|---------------|
| MR SAST gate | 5.10, 5.14 |
| Secret scan | 5.15 |
| SCA + SBOM | 5.16 |
| IaC scan | 5.9, 5.13 (configurations) |
| Container scan | 5.16, 5.20 |
| DAST preprod | 5.11 |
| Pentest checklist | 5.19 |
| Signed artifacts | 5.20, 5.21 |

## Design phase (not CI)

| Activity | GOST | DAF |
|----------|------|-----|
| Threat model | 5.6–5.7 | P-REQ-TM |
| Security requirements | 5.3 | P-REQ-RD |
| Architecture review | 5.6 | P-REQ-CR |

## Evidence artifacts

- SARIF files from sast/sca/secrets jobs
- `sbom.cdx.json` from C1
- `release-gate-checklist.md` sign-off
- DefectDojo export for ASTO (`P-DEFECT-CNS`)

## Related frameworks (xlsx sheets)

- `SAMM_mapping` — OWASP SAMM v2
- `DSOMM_mapping` — DevSecOps maturity model
- `BSIMM14_mapping` — BSIMM14 activities

Do not duplicate 561 rows here — extract on demand with `extract_daf_xlsx.py`.
