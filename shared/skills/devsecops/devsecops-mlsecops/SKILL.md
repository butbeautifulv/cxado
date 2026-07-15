---
name: devsecops-mlsecops
description: >-
  MLSecOps practices from DAF_MLSO for ML/AI systems: data poisoning, PII in
  datasets, ML-BOM, adversarial attacks. Use when extending pipeline for ML
  projects, not for standard app CI/CD.
---

# MLSecOps (optional)

Sources: `docs/references/daf/DAF_MLSO_public_RU.md`, `docs/references/extracts/daf/Практики_MLSecOps.md`

Repo: `docs/10-mlsecops-appendix.md`

**Profile `ai-ml`** — opt-in; not in base P0–F3.

## Phase docs

| Phase | Doc | Gate |
|-------|-----|------|
| ML1 | `docs/phases/ML1-data-scan.md` | PII **block** |
| ML2 | `docs/phases/ML2-ml-bom.md` | warn |
| ML3 | `docs/phases/ML3-model-scan.md` | manual warn |

## CI jobs

| Job | Control |
|-----|---------|
| `ml-data-scan.yml` | `ml_data` |
| `ml-bom.yml` | `ml_bom` |
| `ml-model-scan.yml` | `ml_model` |

Scanner: `scripts/ai-ml-scan.py` (Presidio optional upgrade)

## Gate practices (DAF MLSO)

| ID | Gate |
|----|------|
| T-MLDATA-DT-4-1 | Block build on PII in data |
| T-MLDATA-DT-4-2 | Block on poisoned data (future) |
| T-MLDATA-DT-4-3 | Block on adversarial data (future) |
| T-ADI-ART-ML-3-3 | ML-BOM artifact required |

## Adopt

```bash
./scripts/adopt.sh --profile ai-ml --platform gitlab --target .
```

Demo: `examples/sample-ml-app/`

Details: [reference.md](reference.md)
