# Veil Background Workers — Offline Profile Decision

**Phase:** 6 (P6.1)  
**Verdict for P30 cxado offline:** **`graph-only` + Path C (gate Prometheus scrape)**

## Summary

Veil **ingest**, **pipeline**, and **engage-events** workers are **optional** for the current egregore offline workflow. Default deploy intentionally sets `replicas: 0`. Prometheus previously scraped three worker jobs anyway → **profile drift** (targets DOWN), not a runtime incident.

## Profiles

| Profile | Helm values | Worker deploys | Prometheus `veil-*-worker` jobs | Primary use |
|---------|-------------|----------------|-----------------------------------|-------------|
| `graph-only` | `values-graph-only.yaml` | off (0 replicas) | **absent** (gated) | egregore `ti_search_in_category`, playbooks via MCP |
| `workers-obs` | `+ values-workers-obs.yaml` | on (1 each) | **present** | metrics E2E, ingest/engage smoke |
| `full-loop` | future | on + engage API | on | veneno pentest loop on k3s |

## Dependency matrix

| Workflow | ingest | pipeline | engage-events | scrape CronJob |
|----------|--------|----------|---------------|----------------|
| `ti_search_in_category` (MCP) | No | No | No | No |
| `playbook_search` / `playbook_get` | No | No | No | No |
| Fresh TI corpus ingest | Yes | Yes | No | Yes |
| Veneno → graph (`engage.events`) | Yes (downstream) | No | Yes | No |
| Worker metrics observability | Yes | Yes | Yes | optional |

## Root cause of baseline “3 workers down”

| job_name | Target | graph-only status | Cause |
|----------|--------|-------------------|-------|
| `veil-api` | `veil-veil-api:8090` | up | deployed |
| `veil-mcp` | `veil-veil-mcp:8091` | up | deployed |
| `veil-ingest-worker` | `*-ingest-worker-metrics:9090` | was **down** | replicas=0, no Service |
| `veil-pipeline-worker` | `*-pipeline-worker-metrics:9090` | was **down** | replicas=0, no Service |
| `veil-engage-events-worker` | `*-engage-events-worker-metrics:9090` | was **down** | disabled, no template |

## Fix (Path C — implemented)

1. Remove worker scrape jobs from default `prometheus-k3s.yml`
2. Append `prometheus-k3s-veil-workers-scrape.yaml` when `CXADO_VEIL_PROFILE=workers-obs`
3. Set `global.external_labels.veil_profile` for dashboards/alerts
4. Document `--with-workers-obs` in deploy scripts

## When to enable Path B (`workers-obs`)

- Veneno engage bridge testing on k3s
- Live TI ingest QA (not static graph pack)
- Explicit stakeholder sign-off + Phase 5 capacity headroom

## Cross-links

- Deploy: [deploy/k8s/veil-offline/README.md](../../deploy/k8s/veil-offline/README.md)
- Phase 2: egregore Veil MCP read path
- Audit: `scripts/k8s/audit-veil-workers.sh`
- Phase 9: E2E validation matrix

## Operator UI note

egregore **Next.js UI** (`egregore-ui`) runs in `cxado-app` by default. Deploy: [nexus-egregore-loop.md](../deploy/nexus-egregore-loop.md) (`cxado-nexus-deploy.sh`).
