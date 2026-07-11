# Veil MCP failure analysis (k3s P30)

**Date:** 2026-07-09  
**Cluster:** P30 (`192.168.0.133`)  
**Baseline window:** 7d pre-fix

## Summary

| Tool | Errors (7d) | Success (7d) | Verdict |
|------|-------------|--------------|---------|
| `ti_search_in_category` | 72 | 0 | **Fix: arg normalization + pre-MCP validation** |
| `playbook_procedure` | 10 | 0 | **Fix: require id from playbook_search** |
| `playbook_for_technique` | 8 | 0 | **Fix: technique_id normalization** |
| `playbook_get` | 2 | 0 | Same as playbook_procedure |

Veil MCP itself is healthy (p95 ~7.7 ms). Failures are on the egregore side: invalid LLM args and calls without runtime config bootstrap.

## Hypothesis verdicts

| # | Hypothesis | Verdict | Evidence |
|---|------------|---------|----------|
| H1 | Wrong `VEIL_MCP_URL` (localhost) | **Partial** | k8s env is correct; `call_veil_mcp_tool` without `configure_from_settings` still uses default `http://localhost:8091/mcp` → connection refused |
| H2 | `VEIL_MCP_ENABLED=false` | Rejected | Worker env: `VEIL_MCP_ENABLED=true` |
| H3 | Invalid `category` enum | **Confirmed** | LLM sends `ioc`; veil expects `ti`. Alias mapping added |
| H4 | Wrong field names (`q`/`cat`) | **Confirmed** | `{'q':'test','cat':'ti'}` → `unknown category:` (empty category). Aliases added |
| H5 | Auth token missing | Rejected | `/health` and `tools/call` succeed without token on offline profile |
| H6 | Gateway adapter mutates args | Rejected | Adapter delegates unchanged to `call_veil_mcp_tool` |
| H7 | Hallucinated playbook ids | **Likely** | Pre-MCP slug validation added |
| H8 | `enrich_ioc` wrapper broken | Rejected | Uses correct `query`+`category`; fails only when runtime config not loaded |

## Direct MCP vs agent path

### Direct MCP (worker pod, urllib)

```text
POST http://veil-veil-mcp.veil.svc.cluster.local:8091/mcp
tools/call ti_search_in_category {"category":"ti","query":"185.220.101.1","limit":3}
→ success, nodes returned
```

### Agent path without bootstrap

```text
call_veil_mcp_tool(...)  # no configure_from_settings
→ Connection refused (localhost:8091)
```

### Agent path with bootstrap

```text
get_container() or configure_from_settings(get_settings())
call_veil_mcp_tool('ti_search_in_category', {'category':'ti','query':'...'})
→ success
```

### Invalid LLM args (before fix)

```text
call_veil_mcp_tool('ti_search_in_category', {'q':'test','cat':'ti'})
→ unknown category:  (veil RPC error — empty category, q not mapped)
```

## k3s env audit (P2.3)

| Variable | Worker value | Status |
|----------|--------------|--------|
| `VEIL_MCP_ENABLED` | `true` | OK |
| `VEIL_MCP_URL` | `http://veil-veil-mcp.veil.svc.cluster.local:8091/mcp` | OK |
| `VEIL_MCP_TIMEOUT` | `30` | OK |
| veil-mcp `AUTH_ENABLED` | not set / off | OK for offline |

## Fixes applied (Phase 2)

1. `prepare_veil_tool_invocation()` — alias `q`→`query`, `cat`→`category`, validate category enum, reject empty query before MCP
2. Playbook id slug validation; technique_id `T####` normalization
3. `_ensure_veil_runtime_config()` in `veil_mcp_client` — lazy settings load when URL still default
4. Structured failure logs: `veil_mcp_tool_failed` with `reason` (`invalid_args`, `unavailable`, `remote_error`, …)
5. `smoke_veil_mcp.sh` — ti_health → ti_search → playbook chain

## Verification

```bash
make cxado-smoke-veil-mcp
# or k3s:
CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./projects/egregore/scripts/smoke_veil_mcp.sh
```

PromQL after smoke:

```promql
sum(increase(cys_tool_invocations_total{tool="ti_search_in_category",result="success"}[1h])) > 0
```
