---
name: devsecops-reference-lookup
description: >-
  Lookup tables and full texts in docs/references/: DAF/JCSF extracts, daf md,
  pdftotext archives. Use when auditing sources, verifying docs, or re-generating extracts.
---

# Reference lookup (docs/references/)

Runtime sources are **in-repo** under `docs/references/`. Agents work without a local vendor cache.

## Layout

```
docs/references/
├── daf/                    # DAF_public_RU.md, MLSO, LICENSE
├── extracts/daf/           # xlsx sheet extracts (markdown tables)
├── extracts/jcsf/          # JCSF xlsx extracts
├── extracts/fintech-pdf.txt
├── extracts/tools-map-pdf.txt
├── secure-sdlc-phases.md
├── sdlc-mapping.md
├── daf-kirillamida.md
├── framework-mappings.md
├── fintech-swimlane.md
├── supplements/            # ChatGPT MD views (tools, fintech 12-stage, JCSF overview)
└── cisco-ai-defense.md
```

## Extract scripts (maintainer re-gen)

Requires local xlsx copy; pass path explicitly:

```bash
python scripts/extract_daf_xlsx.py --xlsx /path/to/DAF_public_RU.xlsx --all-sheets
python scripts/extract_jcsf_xlsx.py --xlsx "/path/to/JCSF v7_public.xlsx" --all-sheets
```

Single sheet:

```bash
python scripts/extract_daf_xlsx.py --xlsx /path/to/DAF_public_RU.xlsx \
  --sheet "Кирилламида" --rows 5

python scripts/extract_daf_xlsx.py --xlsx /path/to/DAF_public_RU.xlsx \
  --sheet "ГОСТ56939_mapping" --grep "T-CODE-SST"
```

Python 3 stdlib only. Run from repo root.

## PDF text archives

- `docs/references/extracts/fintech-pdf.txt`
- `docs/references/extracts/tools-map-pdf.txt`

Prefer synthesized docs over raw text.

## xlsx sheet index

| Framework | Key sheets | Extract dir |
|-----------|------------|-------------|
| DAF | Кирилламида, Практики, ГОСТ56939_mapping, miniRoadmap | `extracts/daf/` |
| JCSF | Практики, CIS Kubernetes, CIS Docker | `extracts/jcsf/` |

Full sheet list: run `--all-sheets` or see filenames in extract dirs.

## Synthesized docs + skills

| Source | docs/ | skill |
|--------|-------|-------|
| DAF | `references/daf-kirillamida.md` | `devsecops-daf` |
| Secure SDLC | `references/secure-sdlc-phases.md` | `devsecops-secure-sdlc` |
| Framework mappings | `references/framework-mappings.md` | `devsecops-gost` |
| Fintech swimlane | `references/fintech-swimlane.md` | `devsecops-fintech-sdlc` |
| Fintech 12 stages | `references/supplements/Типовой_процесс_...md` | `devsecops-fintech-sdlc` |
| Tool catalog | `04-tooling-catalog.md` | `devsecops-tooling` |
| Tool supplement | `references/supplements/devsecops_tools.md` | `devsecops-tooling` |
| JCSF | `06-kubernetes-runtime.md` | `devsecops-jcsf` |
| JCSF overview | `references/supplements/JCSF_v7_public.md` | `devsecops-jcsf` |
| MLSecOps | `10-mlsecops-appendix.md` | `devsecops-mlsecops` |

After extraction, update `docs/` — do not commit vendor xlsx/pdf to git.

See [docs/references/extracts/README.md](../../../docs/references/extracts/README.md).
