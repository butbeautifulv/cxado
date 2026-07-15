# Worker job failure taxonomy

**Phase:** 3  
**Code:** `cys_core/domain/workers/failure_reason.py`  
**Finalization:** `cys_core/application/workers/job_finalizer.py` → `finalize_failure()`

## Goal

Answer «why do worker jobs fail?» from Prometheus/Loki without reading every log line. Latency dashboards (`cys_worker_job_duration_seconds_*`) stay unchanged; drill-down uses `cys_worker_job_failures_total{persona,reason}`.

## Canonical reasons

| `reason` | Typical signal | Source |
|----------|----------------|--------|
| `timeout` | `worker_job_timeout`, `recursion_limit_exhausted` | `interfaces/worker/orchestrator.py`, `run_worker_job.py` |
| `tool_error` | `tools_not_executed:*`, MCP remote errors | `run_worker_job.py` |
| `tool_invalid_args` | `tool_invalid_args:*` (Phase 2 pre-MCP reject) | `veil_mcp_client.py` |
| `grounding_rejected` | `ungrounded_finding:*` | SOC evidence gate in `run_worker_job.py` |
| `schema_invalid` | `empty_finding*`, output schema `SecurityViolation` | `run_worker_job.py`, `result_validator.py` |
| `budget_exceeded` | `JobBudgetExceeded` | budget tracker |
| `llm_error` | `model_refusal:*` | `run_worker_job.py` |
| `sandbox_error` | sandbox create/destroy failures | `run_worker_job.py` |
| `security_violation` | input sanitizer `SecurityViolation` | `run_worker_job.py` |
| `cancelled` | `dependency_not_ready:*`, operator cancel, `reconciled_*_bus_job` | orchestrator re-queue / reconcile (not terminal failure) |
| `unknown` | unclassified exception | fallback + alert |

## Egress contract

`job_finished` payload now includes:

```json
{
  "success": false,
  "error": "ungrounded_finding:...",
  "reason": "grounding_rejected",
  "persona": "soc",
  "job_id": "..."
}
```

`budget_exceeded` event is still emitted for backward compatibility when `reason=budget_exceeded`.

## PromQL

```promql
# Top failure reasons (1h)
topk(10, sum(increase(cys_worker_job_failures_total{job="egregore-worker"}[1h])) by (reason))

# By persona
sum(increase(cys_worker_job_failures_total{job="egregore-worker"}[7d])) by (persona, reason)
```

## Loki

```logql
{app="egregore-worker"} | json | event="worker_job_failed"
{app="egregore-worker"} | json | reason="grounding_rejected"
```

## Runbook (first action)

| `reason` | First action |
|----------|--------------|
| `timeout` | Langfuse `worker.agent.run` duration; `WORKER_JOB_TIMEOUT`; vLLM p95 |
| `tool_error` | `topk(tool, cys_tool_invocations_total{result="error"})`; Veil MCP smoke |
| `tool_invalid_args` | Worker logs `veil_mcp_tool_failed reason=invalid_args`; Phase 2 coercion |
| `grounding_rejected` | `worker_grounding_rejected` logs; SIEM sparse runbook |
| `budget_exceeded` | `cys_job_tokens_total`, persona budget env |
| `schema_invalid` | Langfuse persona output sample (redacted) |
| `security_violation` | `cys_sanitizer_blocks_total` |
| `unknown` | Extend `classify_worker_failure()` — file ticket |

## Mapping table (signal → reason)

| Current signal | File | `reason` | Terminal event |
|----------------|------|----------|----------------|
| `TimeoutError` → `worker_job_timeout` | `orchestrator.py` | `timeout` | `job_finished` |
| `recursion_limit_exhausted` | `run_worker_job.py` | `timeout` | `job_finished` |
| `JobBudgetExceeded` | `run_worker_job.py` | `budget_exceeded` | `job_finished` + `budget_exceeded` |
| `SecurityViolation` input | `run_worker_job.py` | `security_violation` | `job_finished` |
| `SecurityViolation` schema | `result_validator.py` | `schema_invalid` | `job_finished` |
| `ungrounded_finding:*` | `run_worker_job.py` | `grounding_rejected` | `job_finished` |
| `tools_not_executed:*` | `run_worker_job.py` | `tool_error` | `job_finished` |
| `empty_finding*` | `run_worker_job.py` | `schema_invalid` | `job_finished` |
| `model_refusal:*` | `run_worker_job.py` | `llm_error` | `job_finished` |
| Sandbox exception | `run_worker_job.py` | `sandbox_error` | `job_finished` |
| Unclassified | catch-all | `unknown` | `job_finished` + alert |
