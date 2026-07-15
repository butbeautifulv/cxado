# MLSecOps integration notes

## When to enable

- Training pipelines in repo
- RAG / embedding datasets versioned in git or artifact store
- Model artifacts deployed to K8s inference

## Pipeline placement

```
MR → ml-data-scan (warn/block PII)
Build → sbom.cdx.json + ml-bom.json
Preprod → ml-model-scan (adversarial)
Prod → runtime guardrails (out of CI)
```

## Policy extension

Add section to `config/security-gate-policy.yaml`:

```yaml
ml_data:
  mode: block
  block_pii: true
  block_poisoning_indicators: true
```

## DAF lookup

```bash
rg "T-MLDATA" docs/references/daf/DAF_MLSO_public_RU.md
python scripts/extract_daf_xlsx.py --xlsx /path/to/DAF_public_RU.xlsx \
  --sheet "Практики+MLSecOps" --rows 10
```

## PR scope

Same rules: ≤5 files, new skill doc + job + policy + phase md
