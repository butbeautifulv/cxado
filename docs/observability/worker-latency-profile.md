# Worker latency profile (k3s P30 baseline)

**Date:** 2026-07-09  
**Cluster:** P30 offline  
**Purpose:** Phase 4 tuning evidence — where wall-clock is spent before mitigations.

## Dominant patterns (baseline)

| Persona | Total s (p95) | agent.run est. | tool.invoke est. | Top tools | Pattern |
|---------|---------------|----------------|------------------|-----------|---------|
| soc | **600** (timeout ceiling) | ~300–400 | ~60–120 | `investigate_incident`, `search_events` | SIEM loops + late emit finding |
| intel | **~300** | ~200 | ~40–80 | `ti_search_in_category`, `enrich_ioc` | Veil retries + late IntelFinding |
| consultant | varies | high token | `playbook_*` | Large playbook bodies in context |

vLLM inference alone ~63s avg / ~182s p95 — **not** the primary bottleneck; multi-step loops dominate.

## Phase 4 mitigations applied

| Lever | Change |
|-------|--------|
| Tool dedup | Block 3rd identical call (soc/intel) |
| Tool cache | `ti_list_categories`, `playbook_search` per job |
| Output truncate | `playbook_get` 3k, `playbook_procedure` 4k chars |
| SIEM drilldown | max **2** (was 3) |
| Emit nudge | soc/intel after **4** tools (was 6/5) |
| Agent retries | triage **2** attempts (was 3) |
| Persona budgets | soc/intel **6** tool calls, **40k** tokens |
| Soft timeout | salvage at **90%** wall clock |
| Budget salvage | `JobBudgetExceeded` → partial finding |
| k3s timeout | **300s** (was 360s) |

## Verification PromQL (after deploy)

```promql
histogram_quantile(0.95, sum(rate(cys_worker_job_duration_seconds_bucket{persona="soc"}[1h])) by (le))
sum(increase(cys_worker_job_salvaged_total{persona="soc"}[1h])) by (reason)
sum(increase(cys_worker_job_failures_total{persona="soc",reason="timeout"}[1h]))
```

## Targets (interim)

| Metric | Baseline | Target |
|--------|----------|--------|
| soc p95 duration | 600s | < 480s interim; < 360s stretch |
| soc error ratio 7d | ~100% | ↓ 20% relative |
| tool.invoke count / soc job | high | ↓ 25% |
| grounding rejections | baseline | no ↑ |
