# Architecture site — content outline

SSOT for section IDs, diagram registry, and markdown cross-links.

## Site metadata

| Field | Value |
|-------|-------|
| Title | cxado — архитектура платформы |
| Language | RU (technical) |
| Base path | `/docs/architecture-site/` |
| k3s URL | `https://<host>:30080` |
| Offline | Mermaid bundled in `js/mermaid.min.js`, no CDN |

## Navigation (section anchors)

| # | Anchor | Title | Source docs |
|---|--------|-------|-------------|
| 1 | `#ecosystem` | Обзор cxado | `docs/ecosystem-map.md`, `docs/adr/cxado-architecture.md` |
| 2 | `#egregore-planes` | Egregore — три плоскости | `projects/egregore/docs/ARCHITECTURE.md` |
| 3 | `#ddd-layers` | DDD-слои Egregore | `projects/egregore/docs/PLATFORM_TRUTH_MAP.md` |
| 4 | `#personas` | Personas, plans, skills | `projects/egregore/agents/manifest.yaml` |
| 5 | `#data-flow` | Data flow: event → worker | `interfaces/ingress/router.py`, `run_worker_job.py` |
| 6 | `#memory` | Memory (4 слоя) | `cys_core/domain/memory/` |
| 7 | `#tooling` | Tooling & datasources | `interfaces/gateways/tool/`, RAG, Veil MCP |
| 8 | `#guardrails` | Guardrails & policy | `domain/security/`, `policy_resolver.py` |
| 9 | `#hitl` | HITL L1 / L2 | middleware, `critic_service.py`, UI `/approvals` |
| 10 | `#evals` | Evals | `domain/eval/`, Langfuse judge, trajectory adapters |
| 11 | `#observability` | Observability | `docs/OBSERVABILITY.md` |
| 12 | `#integrations` | Интеграции | `docs/integration/` |
| 13 | `#k3s-topology` | k3s offline topology | `deploy/k8s/*-offline/` |
| 14 | `#references` | Markdown-канон | links to repo docs |

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

## Markdown SSOT links (footer)

- [ecosystem-map.md](../../ecosystem-map.md)
- [cxado-architecture ADR](../../adr/cxado-architecture.md)
- [egregore ARCHITECTURE.md](../../projects/egregore/docs/ARCHITECTURE.md)
- [egregore OBSERVABILITY.md](../../projects/egregore/docs/OBSERVABILITY.md)
- [egregore SECURE_DEPLOYMENT.md](../../projects/egregore/docs/SECURE_DEPLOYMENT.md)
- [integration index](../../integration/README.md)
