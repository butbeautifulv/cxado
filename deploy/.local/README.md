# Local deploy artifacts (gitignored)

Runtime output from k3s deploy, validation gate, and benchmark scripts. **Do not commit.**

Default path: `deploy/.local/logs/` (override with `CXADO_ARTIFACTS_DIR`).

| Subdir | Produced by |
|--------|-------------|
| `k3s-baseline/` | `make k3s-baseline`, `collect-k3s-cluster-snapshot.sh` |
| `k3s-validation/` | `make k3s-validation-gate`, `run-validation-scenarios.sh` |
| `e2e_verify_*.log` | `e2e-verify-egregore.sh` |
| `benchmark_*.json` | `benchmark-*.sh`, `langfuse-benchmark-report.sh` |
| `cxado_k3s_*.md` | `k3s-deploy-cxado-offline.sh` |

See [docs/DOCUMENTATION.md](../../docs/DOCUMENTATION.md) and [docs/observability/README.md](../../docs/observability/README.md).
