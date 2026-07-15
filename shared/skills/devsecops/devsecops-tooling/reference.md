# Tool catalog — extended reference

Canonical tiers: [04-tooling-catalog.md](../../docs/04-tooling-catalog.md).  
Exhaustive OCR: [supplements/devsecops_tools.md](../../docs/references/supplements/devsecops_tools.md).  
Full CI/CD map: [SKILL.md](SKILL.md) § Full CI/CD.

## CI-integrated (SARIF → gate-check → DefectDojo)

See oss-full-shared table; producers under `templates/gitlab/jobs/` and `templates/github/workflows/jobs/oss/`.

## Runtime / edge (NOT default CI jobs)

| Class | OSS examples | Template path |
|-------|--------------|---------------|
| RASP | OpenRASP, Falco (container) | [F2-rasp-waf.md](../../docs/phases/F2-rasp-waf.md), [k8s/runtime/](../../templates/k8s/runtime/) |
| WAF | ModSecurity, CRS | F2 runbook |
| API Sec | 42Crunch, Gravitee, QAPISec, StackHawk | F2 runbook; supplement |
| IAST | ZAP Full Scan (+ commercial optional) | [F1-iast.md](../../docs/phases/F1-iast.md), `iast-preprod.*` |
| CWPP | Falco, kube-bench | [E3-falco.md](../../docs/phases/E3-falco.md) |
| Admission | Kyverno, OPA, Conftest | [k8s/admission/](../../templates/k8s/admission/) |
| Network | Cilium, NetworkPolicy | [k8s/network/](../../templates/k8s/network/) |
| SIEM | Falco/WAF/RASP events | [E4-siem.md](../../docs/phases/E4-siem.md) |

## QA / design (optional CI)

| Class | OSS examples | Template |
|-------|--------------|----------|
| **API fuzz** | **Schemathesis** | `api-fuzz-schemathesis.yml`, `api-fuzz-oss.yml` |
| **Binary fuzz** | AFL++, Go `-fuzz`, Jazzer | `binary-fuzz.yml`, `binary-fuzz-oss.yml`, `examples/fuzzing/` |
| Binary fuzz (alt) | libFuzzer, Honggfuzz, Sydr | extend `scripts/run-binary-fuzz.sh` |
| DAST alt | Nuclei, Nikto, Wapiti | supplement |
| BCA | Ghidra, JADX, radare2 |
| Taint | design-phase (SecChamp) |
| MAST | MobSF, QARK |

## Mobile / codec

ProGuard, DexGuard — out of base template.

## Integration contract

All **CI** scanners → SARIF (or SBOM JSON) → `security-gate-policy.yaml` → optional `aspm-export.py` → DefectDojo.

RASP/WAF → alerting/SIEM only; **never** block MR by default.
