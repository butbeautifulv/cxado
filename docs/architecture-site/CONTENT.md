# Architecture site — content outline

SSOT for section IDs, diagram registry, and markdown cross-links.

## Site metadata

| Field | Value |
|-------|-------|
| Title | cxado — архитектура платформы |
| Language | RU (technical) |
| Base path | `/docs/architecture-site/` |
| k3s URL | `https://<host>:30080` |
| Local preview | `http://127.0.0.1:8765` |
| Offline | Mermaid bundled in `js/mermaid.min.js`, no CDN |

## Navigation (section anchors)

| # | Anchor | Title | Source docs |
|---|--------|-------|-------------|
| 0 | `#services` | Сервисы k3s | `js/services.js`, deploy ports |
| 1 | `#ecosystem` | Обзор cxado | `docs/ecosystem-map.md`, `docs/adr/cxado-architecture.md` |
| 2 | `#egregore-planes` | Egregore — три плоскости (+ target 5 ролей) | `projects/egregore/docs/ARCHITECTURE.md` |
| 3 | `#ddd-layers` | DDD-слои Egregore | `ARCHITECTURE.md`, `ARCHITECTURE_DEBT.md`, `application/ports/` |
| 3b | `#arch-gates` | Import boundaries & arch gates | `scripts/verify_import_boundaries.py`, `ARCHITECTURE_DEBT.md` |
| 4 | `#personas` | Personas, plans, skills | `agents/manifest.yaml`, `CATALOG_SEED.md` |
| 4b | `#engagement` | Engagement lifecycle | `domain/engagement/models.py`, `StartEngagement` |
| 5 | `#data-flow` | Data flow: event → worker | `ARCHITECTURE.md` (worker.jobs), `run_worker_job.py` |
| 6 | `#memory` | Memory (4+ слоя) | `domain/memory/`, `domain/memory/records.py` |
| 7 | `#tooling` | Tooling & datasources | `DATASOURCES_RBAC.md`, gateways, Veil MCP |
| 8 | `#guardrails` | Guardrails & policy | `policy_resolver.py`, `guardrails/policy_gate.py` |
| 9 | `#hitl` | HITL L1 / L2 | middleware, `critic_service.py`, UI `/approvals` |
| 10 | `#evals` | Evals | `application/eval/`, runbooks, UI `/eval` `/compare` |
| 11 | `#observability` | Observability | `OBSERVABILITY.md`, Grafana `egregore-eval` |
| 12 | `#local-dev` | Local-first dev | `deploy/README.md`, `make cxado-up-minimal` |
| 13 | `#integrations` | Интеграции | `docs/integration/`, `egregore-siem-mcp.md`, `egregore-veil-mcp.md` |
| 14 | `#k3s-topology` | k3s offline topology | `deploy/k8s/*-offline/`, `siem-mcp` helm |
| 15 | `#references` | Markdown-канон | links to repo docs |

## Diagram registry

| ID | File | UML type | Used in section |
|----|------|----------|-----------------|
| `D01` | `diagrams/ecosystem.mmd` | Component (C4) | `#ecosystem` |
| `D02` | `diagrams/egregore-planes.mmd` | Component | `#egregore-planes` |
| `D03` | `diagrams/ddd-layers.mmd` | Package | `#ddd-layers` |
| `D04` | `diagrams/data-flow.mmd` | Sequence | `#data-flow` |
| `D05` | `diagrams/memory-layers.mmd` | Component | `#memory` |
| `D06` | `diagrams/tool-gateway.mmd` | Component | `#tooling` |
| `D07` | `diagrams/security-layers.mmd` | Flow | `#guardrails` |
| `D08` | `diagrams/hitl-l1.mmd` | Sequence | `#hitl` |
| `D09` | `diagrams/hitl-l2.mmd` | Sequence | `#hitl` |
| `D10` | `diagrams/job-state.mmd` | State | `#hitl` |
| `D11` | `diagrams/obs-stack.mmd` | Component | `#observability` |
| `D12` | `diagrams/k3s-topology.mmd` | Deployment | `#k3s-topology` |
| `D13` | `diagrams/local-dev-topology.mmd` | Deployment | `#local-dev` |
| `D14` | `diagrams/engagement-flow.mmd` | Sequence | `#engagement`, `#egregore-planes` |
| `D15` | `diagrams/planes-target.mmd` | Component | `#egregore-planes` |
| `D16` | `diagrams/import-boundaries.mmd` | Package | `#arch-gates` |

## Markdown SSOT links (footer)

- [ecosystem-map.md](../../ecosystem-map.md)
- [cxado-architecture ADR](../../adr/cxado-architecture.md)
- [egregore_unified_masterplan.md](../../egregore_unified_masterplan.md)
- [K3S_DEPLOY_BACKLOG.md](../../K3S_DEPLOY_BACKLOG.md)
- [deploy/README.md](../../deploy/README.md)
- [egregore ARCHITECTURE.md](../../projects/egregore/docs/ARCHITECTURE.md)
- [egregore ARCHITECTURE_DEBT.md](../../projects/egregore/docs/ARCHITECTURE_DEBT.md)
- [egregore OBSERVABILITY.md](../../projects/egregore/docs/OBSERVABILITY.md)
- [DATASOURCES_RBAC.md](../../projects/egregore/docs/DATASOURCES_RBAC.md)
- [SGR reasoning](../../projects/egregore/docs/integration/sgr-reasoning.md)
- [egregore SECURE_DEPLOYMENT.md](../../projects/egregore/docs/SECURE_DEPLOYMENT.md)
- [integration index](../../integration/README.md)
- [egregore-siem-mcp](../../integration/egregore-siem-mcp.md)
