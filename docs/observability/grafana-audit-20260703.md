# Grafana Production Audit Report

**Date:** 2026-07-03  
**Scope:** 8 dashboards (vLLM frozen — not audited for changes)  
**Method:** SRE operational-decision test per panel

> *"What operational decision can an SRE make from this graph?"* — if none → REMOVE.

---

## Summary

| Dashboard | Panels (before) | Panels (after) | No Data risk | Duplicates | KEEP | REMOVE | MERGE | FIX | Score |
|-----------|----------------:|---------------:|-------------:|-----------:|-----:|-------:|------:|----:|------:|
| cxado-overview | 12 | 13 | 0 | 0 | 13 | 0 | 0 | 1 | 9.2/10 |
| egregore-cys-agi | 20 | 18 | 2 | 3 | 15 | 3 | 0 | 3 | 7.5→9.0 |
| egregore-observability | 11 | 8 | 1 | 4 | 6 | 3 | 1 | 1 | 7.0→8.5 |
| egregore-sgr | 7 | 7 | 0 | 0 | 7 | 0 | 0 | 0 | 8.5/10 |
| veil-graph | 8 | 8 | 0 | 2 | 8 | 0 | 0 | 0 | 8.8/10 |
| veil-observability | 8 | 8 | 1 | 2 | 8 | 0 | 0 | 1 | 8.0→8.5 |
| infra-host | 10 | 9 | 0 | 1 | 8 | 0 | 1 | 0 | 8.5→9.0 |
| infra-k3s | 8 | 8 | 0 | 0 | 8 | 0 | 0 | 0 | 9.0/10 |
| **Total** | **84** | **82** | — | **12** | **75** | **6** | **2** | **6** | — |

**Panel reduction:** duplicates removed; operational panels added (RAG, tools, trust, bypass). vLLM dashboard frozen.

**Deploy status:** k3s offline — run `obs-deploy-dashboards.sh` when cluster is reachable.

---

## cxado-overview (`cxado-overview`)

| Panel | Verdict | Operational decision |
|-------|---------|---------------------|
| Platform Health (row) | KEEP | Section header |
| Egregore API | KEEP | Is SOC API scrape healthy? |
| Veil API | KEEP | Is Veil API scrape healthy? |
| Veil MCP | KEEP | Is Veil MCP scrape healthy? |
| vLLM | **FIX** (added) | Is inference endpoint reachable? → drill to vLLM dash |
| Prometheus | KEEP | Is metrics backend up? |
| Tempo | KEEP | Is tracing backend up? |
| Loki | KEEP | Is log backend up? |
| Executive Summary (row) | KEEP | Section header |
| HITL Pending | KEEP | Are approvals backing up? (canonical executive KPI) |
| Active Investigations | KEEP | How much SOC workload is open? |
| Events / sec | KEEP | Is event pipeline flowing? |
| Veil 5xx / sec | KEEP | Are users hitting server errors? |

---

## egregore-cys-agi (`egregore-cys-agi`)

| Panel | Verdict | Operational decision |
|-------|---------|---------------------|
| Scrape Targets (row) | KEEP | — |
| API, Prometheus, Tempo, Loki | KEEP | Scrape health for Egregore stack |
| Platform overview (row) | **REMOVE** | Duplicates cxado-overview |
| Events / sec | **REMOVE** | Duplicate — use cxado-overview |
| HITL pending | **REMOVE** | Duplicate — use cxado-overview |
| Active investigations | **REMOVE** | Duplicate — use cxado-overview |
| Ingress & Workers (row) | **FIX** (rename) | Consistent casing |
| Events ingested by type | KEEP | Which event types are spiking? |
| Worker job duration p95 | KEEP | Are personas slow? |
| Worker jobs by persona & status | KEEP | Failure rate by persona? |
| Security (row) | KEEP | — |
| Sanitizer blocks | **FIX** (layout) | Was orphaned at x=12; now full width pair |
| Approval bypass attempts | **FIX** (added) | Are HITL bypass attacks occurring? |
| RAG & Tools (row) | **FIX** (added) | New section |
| RAG retrievals / sec | **FIX** (added) | Is RAG being used / denied? |
| Tool invocations / sec | **FIX** (added) | Which tools fail? |
| Cost & Trust (row) | **FIX** (rename from Denial of wallet) | — |
| Job tokens / sec | KEEP | Token burn rate by persona |
| Job cost USD / sec | KEEP | Cost burn rate by persona |
| Agent trust score | **FIX** (added) | Trust config per persona |
| Policy (row) | **FIX** (rename from Policy drift) | — |
| Catalog version | KEEP | Did policy catalog change? |

---

## egregore-observability (`egregore-observability`)

| Panel | Verdict | Operational decision |
|-------|---------|---------------------|
| Health (row) | KEEP | — |
| API | KEEP | Minimal health — full scrape on cys-agi |
| Tempo | **REMOVE** | Duplicate — link to cys-agi / cxado-overview |
| Loki | **REMOVE** | Duplicate |
| Prometheus | **REMOVE** | Duplicate |
| Logs (Loki) (row) | KEEP | — |
| Egregore Application Logs | KEEP | Debug by correlation ID |
| Error Logs | KEEP | Error triage |
| Traces (Tempo) (row) | KEEP | — |
| Recent Egregore Traces | KEEP | Trace search |
| Trace Rate (Span Metrics) | **MERGE→FIX** | Renamed "Tempo Span Ingress Rate"; fixed legend |

---

## egregore-sgr (`egregore-sgr`)

All panels KEEP — focused middleware dashboard. Design system alignment only.

---

## veil-graph (`veil-graph`)

All panels KEEP. Health row intentionally minimal (API + MCP + aggregate RPS). RED metrics canonical here.

---

## veil-observability (`veil-observability`)

| Panel | Verdict | Operational decision |
|-------|---------|---------------------|
| Service Health (row) | KEEP | — |
| veil-api, veil-mcp | KEEP | HTTP scrape health |
| NATS | KEEP | Is messaging plane up? (requires KSM) |
| service variable | **FIX** | Unified with veil-graph (query-driven) |
| Veil Pod Logs | KEEP | Log triage |
| Tempo — veil-mcp | KEEP | Trace search |

---

## infra-host (`cxado-infra-host`)

| Panel | Verdict | Operational decision |
|-------|---------|---------------------|
| Host Summary KPIs | KEEP | Disk, memory, CPU, load at a glance |
| Memory Available (timeseries) | **MERGE** | Removed — stat KPI sufficient with sparkline via graph_mode |
| CPU Usage (%) | KEEP | CPU trend |
| Disk Usage by Mountpoint | KEEP | Which mount is filling? |

---

## infra-k3s (`cxado-infra-k3s`)

All panels KEEP. Threshold and unit alignment to design system.

---

## Design System Applied

| Rule | Value |
|------|-------|
| Success | `#73BF69` |
| Warning | `#FFB357` |
| Error | `#F2495C` |
| Info / throughput | `#5794F2` |
| Accent | `#F2CC0C` |
| Executive KPI row | w=4, h=4 |
| Primary charts | w=12, h=8 |
| No-data (optional metrics) | `or vector(0)` + description |
| Health `up{}` | Never vector(0) — show DOWN |

---

## Frozen

`infra/vllm-monitoring.json` — not modified. Linked from cxado-overview and infra-host only.
