# Gap analysis — docs vs code

Аудит drift для architecture-site. Обновлено после local-first platform waves (2026-07).

**Masterplan rollup (archived):** [archive/egregore_unified_masterplan.md](../archive/egregore_unified_masterplan.md). Active plan: [projects/egregore/docs/MASTER_PLAN_SECURE_PLATFORM.md](../../projects/egregore/docs/MASTER_PLAN_SECURE_PLATFORM.md).

## FIXED (site synced)

| Topic | Was | Now |
|-------|-----|-----|
| Datasource domain | GAPS claimed «no domain entity» | `cys_core/domain/datasources/` + `DATASOURCES_RBAC.md` — site §tooling updated |
| Eval adapters path | `application/evals/` | `application/eval/adapters.py` + `scripts/evals/egregore_eval.py` + tests |
| Observability local | ARCHITECTURE Langfuse-only | `OBSERVABILITY.md` trace matrix; compose Grafana `datasources.compose*.yml`; `make cxado-validate-grafana` |
| Worker queue | Per-persona topics (legacy) | Single `worker.jobs` in code; k8s topic migration deferred ([K3S_DEPLOY_BACKLOG](../K3S_DEPLOY_BACKLOG.md)) |
| RunKernel | Dual paths undocumented on site | `RunKernelPort` / `AgentRunKernel` — site §ddd-layers |
| Catalog prod | Hybrid FS merge implied | API-only seed; `USE_DYNAMIC_CATALOG=true`, `USE_MEMORY_FALLBACK=false` |
| Hexagonal refactor (Phases 1–8) | WorkerOrchestrator god object; PlanInvestigation; PLATFORM_TRUTH_MAP footer | EnqueueWorkerJobs/OrchestrationPort; EngagementPlan; ARCHITECTURE_DEBT.md; §arch-gates on site |
| Orchestration enqueue | WorkerOrchestrator enqueue + execute | D02/D04; §data-flow — application orchestration, orchestrator dequeue only |
| Application boundaries | not documented on site | §arch-gates; D16; `verify_import_boundaries.py` |
| Worker pipeline | monolithic RunWorkerJob implied | §data-flow — five pipeline services |
| Observability ports | metrics/tracing inline implied | §arch-gates, §ddd-layers — MetricsPort, CorrelationIdPort adapters |
| Engagement lifecycle | store field mutation implied | §engagement, D14 — domain lifecycle methods |
| Footer ARCHITECTURE_DEBT | PLATFORM_TRUTH_MAP.md (missing) | §references → ARCHITECTURE_DEBT.md |
| k3s UI :30300 | Site labeled egregore-ui / Next.js | Next.js egregore-ui + same-origin API via gateway |
| SIEM MCP integration | Legacy `query_siem_readonly` only | maxpatrol-siem-mcp + curated tools + `siem-investigation` skill |
| services.js internal | No siem-mcp row | siem-mcp cxado-app:8094 ClusterIP |

## Intentionally partial (truthful on site)

| Topic | Status | Notes |
|-------|--------|-------|
| Batch eval adapters | **skeleton wired** | RAGAS, BFCL, AgentBench, τ2 — not full CI suites |
| Veneno MCP | partial | HITL on high-risk tools |
| k3s deploy gates | **pending** | que-07/08, cat-07, E2E P4–P9 — cluster required |
| Loki/Tempo in minimal | empty panels | Expected in `cxado-up-minimal` Grafana |

## Naming (cys-agi vs egregore) — intentional, do not rename

| Location | Name | Notes |
|----------|------|-------|
| Grafana dashboard uid | `egregore-cys-agi` | Historical uid; keep |
| Prometheus metrics | `cys_*` prefix | Package `cys_core` |
| `agents/manifest.yaml` | alias `cys-agi` | Product layer only |
| Repo / path | `egregore` | Canonical GitHub repo name |

## Cross-links (synced)

| File | Status |
|------|--------|
| `docs/integration/README.md` | SIEM / Tenable / DefectDojo MCP rows |
| `docs/ecosystem-map.md` | MCP repos in catalog + diagram |

## Port matrix

| Port | Service | Doc |
|------|---------|-----|
| 8765 | Local static preview | this README |
| 30080 | Architecture site (k3s TLS) | `deploy/ports.md` |
| 3002 | Grafana (compose) | `deploy/README.md` |
| 3001 | Langfuse (compose) | `OBSERVABILITY.md` |
