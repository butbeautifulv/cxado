# Gap analysis — docs vs code (P0.2)

Generated for architecture-site sync. Items marked **fixed in P3** are addressed by doc updates in this PR.

## Naming drift (cys-agi → egregore)

| File | Issue | Action |
|------|-------|--------|
| `projects/egregore/docs/ARCHITECTURE.md` | Title and body use `cys-agi` | **P3.1** rename to egregore |
| `projects/egregore/docs/README.md` | Title «Документация cys-agi» | **P3.1** |
| `projects/egregore/docs/SECURE_DEPLOYMENT.md` | CLI examples `cys-agi` | **P3.1** partial (CLI is `egregore`) |
| `projects/egregore/agents/README.md` | «продуктовый слой cys-agi» | out of scope (product layer name in manifest still `cys-agi`) |
| Agent skills SKILL.md files | cys-agi integration sections | intentional product alias in skills |

## Missing cross-links

| File | Issue | Action |
|------|-------|--------|
| `projects/egregore/docs/README.md` | No OBSERVABILITY.md, PLATFORM_TRUTH_MAP | **P3.1** |
| Root `README.md` | No architecture site link | **P3.2** |
| `docs/ecosystem-map.md` | No arch site / port 30080 | **P3.2** |
| `docs/integration/README.md` | No diagram references | **P3.3** |
| `projects/egregore/AGENTS.md` / AGENTS.md | No arch site for architects | **P3.3** |

## Stale technical content

| Topic | Docs say | Code truth | Action |
|-------|----------|------------|--------|
| Observability | ARCHITECTURE mentions Langfuse + Prometheus only | OTEL→Tempo, Loki/Promtail added | **P3.1** update observability section |
| Middleware order | Not in ARCHITECTURE.md | PLATFORM_TRUTH_MAP §P0.1 | **P3.1** add summary |
| Eval adapters | Not documented | RAGAS/tau2/BFCL stubs in `application/evals/` | Site §evals marks as stub |
| Datasources | Planned RBAC plan exists | No domain entity; RAG+Veil+SIEM are sources | Site §tooling clarifies |
| Grafana dashboard path | OBSERVABILITY cites old path | `deploy/observability/grafana/dashboards/egregore/` | **P3.1** if touched |
| Worker count | README says 7 agents | manifest has 15 workers + 2 control | Site uses manifest; README optional fix |

## Port matrix

| Port | Service | Action |
|------|---------|--------|
| 30080 | Architecture docs site (k3s offline TLS gateway) | **P0.3 / P2.2** add to deploy/ports.md |

## Intentionally not fixed (truthful site)

- Batch eval runners (RAGAS, tau2) — skeleton only; documented on site as **stub**
- `ProcessFindingCritic` — lightweight; L2 logic primarily in `CriticService`
- Veneno MCP — partial integration; site matches integration README
