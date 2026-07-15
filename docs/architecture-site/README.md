# Architecture site

Статический RU-лендинг архитектуры cxado / Egregore для проектировщиков, security review и offline k3s. Диаграммы Mermaid рендерятся offline (`js/mermaid.min.js`, без CDN).

Фактический контент: [index.html](index.html), outline — [CONTENT.md](CONTENT.md), drift — [GAPS.md](GAPS.md).

## Иерархия SSOT

| Приоритет | Источник | Когда обновлять |
|-----------|----------|-----------------|
| 1 | Код + `projects/egregore/docs/*.md` | Любое архитектурное изменение |
| 2 | [archive/egregore_unified_masterplan.md](../archive/egregore_unified_masterplan.md) | Historical rollup only |
| 3 | [projects/egregore/docs/MASTER_PLAN_SECURE_PLATFORM.md](../../projects/egregore/docs/MASTER_PLAN_SECURE_PLATFORM.md) | Active product master plan |
| 4 | [CONTENT.md](CONTENT.md) | Новая секция / diagram ID |
| 4 | [diagrams/](diagrams/) (`*.mmd`) | Изменение потоков или топологии |
| 5 | [index.html](index.html) | Текст таблиц, ссылки, registry |
| 6 | [GAPS.md](GAPS.md) | Закрытие drift docs ↔ code |
| 7 | **README.md** (этот файл) | Сводка команд, streams, чеклист sync |

## Архитектурные потоки (Streams A–G)

Сжатая карта из unified masterplan (rollup: **301/328 completed**, ~25 k3s deploy gates pending).

| Stream | Решение | Ключевые артефакты |
|--------|---------|-------------------|
| **A Deploy** | k3s E2E, Kafka drain, obs gates — **deferred** | [K3S_DEPLOY_BACKLOG.md](../K3S_DEPLOY_BACKLOG.md) |
| **B Queue** | Один Kafka topic `worker.jobs`, persona в payload | `kafka_topics.py`, `kafka_queue.py` |
| **C Catalog** | Prod: Postgres only; seed `POST /catalog/seed` | `hybrid_registry.py`, `CATALOG_SEED.md` |
| **D Platform** | `RunKernelPort`, SGR hybrid/iron, eval plane, quality routing | `agent_run_kernel.py`, `application/eval/`, `middleware/sgr_*` |
| **E Datasources** | GET-only default, staging, write-gate | `domain/datasources/`, `DATASOURCES_RBAC.md` |
| **F Python** | Async boundaries, resource lifecycle, task supervisor | `PYTHON_RUNTIME_HARDENING.md` |
| **G Architecture refactor** | Phases 1–8 completed: hexagonal ports, domain purity, arch gates | `ARCHITECTURE_DEBT.md`, site §arch-gates, `verify_import_boundaries.py` |

## Local preview (static site)

```bash
cd docs/architecture-site
python3 -m http.server 8765
# http://127.0.0.1:8765
```

## Local-first stack (проверка obs / e2e)

Не разворачивает сам static site — для живых метрик и трасс:

```bash
make cxado-up-minimal          # postgres, redis, langfuse, prometheus, grafana
make cxado-up-veil             # опционально: neo4j, veil-api, veil-mcp
make cxado-up-siem-mcp         # опционально: maxpatrol-siem-mcp :8094
WORKER_REPLICAS=1 make -C projects/egregore dev-api   # + dev-worker отдельно
make cxado-validate-grafana
make cxado-local-e2e
```

- UI host-dev: `EGREGORE_API_UPSTREAM=http://127.0.0.1:8080` в `projects/egregore/ui/.env.local` (Next.js Operator UI :3000)
- k3s offline UI: Next.js `egregore-ui` на :30300 (same-origin API) и :30301
- Grafana compose datasources → `prometheus:9090` (не k8s DNS)
- Runbook: [deploy/README.md](../../deploy/README.md), [OBSERVABILITY.md](../../projects/egregore/docs/OBSERVABILITY.md)

## k3s offline deploy

```bash
./scripts/k8s/k3s-sync-arch-docs-credentials.sh
./scripts/k8s/k3s-deploy-arch-docs-offline.sh
```

App deploy (canonical): [docs/deploy/nexus-egregore-loop.md](../deploy/nexus-egregore-loop.md). **DEPRECATED:** `k3s-offline-bundle-*.sh` (fallback only).

URL: `https://<k3s-node>:30080`

## Реестр контента

- Секции и diagram IDs **D01–D16**: [CONTENT.md](CONTENT.md)
- При добавлении секции: sidebar в `index.html` + запись в `js/diagrams.js`

## Чеклист синхронизации (после изменения архитектуры)

1. Обновить канонический `.md` в `projects/egregore/docs/`
2. После Phase N arch refactor → обновить §arch-gates + D03/D04 + GAPS
3. При изменении backlog — `python3 scripts/plan/build-unified-masterplan.py`
4. Правка `diagrams/*.mmd` → проверка рендера в браузере (:8765)
5. Синк секций `index.html` + footer references
6. Обновить [GAPS.md](GAPS.md)
7. k3s: `./scripts/k8s/k3s-deploy-arch-docs-offline.sh` (arch-docs only)

## Credentials

`js/credentials.js` — **gitignored**, только test lab. Не коммитить пароли.

## Notes

- Mermaid vendored: `js/mermaid.min.js` (~3.5 MB)
- Eval batch adapters (RAGAS, BFCL, τ2) — **skeleton**; на сайте помечены явно
