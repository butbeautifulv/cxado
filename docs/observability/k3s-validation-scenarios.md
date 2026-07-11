# K3s validation scenarios (Phase 9)

Controlled end-to-end paths via egregore worker + tools. Run via:

```bash
CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/run-validation-scenarios.sh
VALIDATION_SCENARIO=S2 ./scripts/k8s/run-validation-scenarios.sh
```

Results: `deploy_logs/k3s-validation/scenarios_*.json` (gitignored).

## Scenario S1 — Consultant + Veil playbook

| Field | Value |
|-------|-------|
| Event | `manual.investigation` |
| Goal | `Разбор фишинга: найди playbook и процедуру реагирования` |
| Expected personas | `consultant` |
| Tools | `playbook_search` → `playbook_get` or `playbook_procedure` |
| Pass | investigation `closed` or job `completed`; `findings_summary` non-empty **or** completed job |
| Prometheus | `increase(cys_tool_invocations_total{tool=~"playbook_.*",result="success"}[1h])` > 0 |

## Scenario S2 — Intel + `ti_search_in_category`

| Field | Value |
|-------|-------|
| Event | `manual.investigation` |
| Goal | `Проверь IOC 185.220.101.1 в threat graph` |
| Persona | `intel` |
| Tools | `ti_list_categories` → `ti_search_in_category` |
| Pass | investigation completes; **no** `tool_error` on `ti_search_in_category` in validation window |
| Blocking | Phase 2 regression — must not be 100% error |

## Scenario S3 — SOC + SIEM sparse

| Field | Value |
|-------|-------|
| Event | `manual.investigation` |
| Goal | `Разбери SIEM инцидент: sparse telemetry, не выдумывай PID/cmdline` (override: `SOC_VALIDATION_GOAL`) |
| Persona | `soc` |
| Tools | `investigate_incident` (may return sparse manifest) |
| Pass | job `completed` with `telemetry_level=sparse` **or** `reason=timeout` with salvage; **no** invented grounding |
| Skip | if SIEM MCP unreachable → CONDITIONAL (document in report) |

Env:

```bash
VALIDATION_SCENARIO=S1|S2|S3|ALL   # default ALL
VALIDATION_POLL_TIMEOUT=600        # per scenario
SOC_VALIDATION_GOAL="..."          # S3 only
```

## Quality spot-check (P9.6)

For each scenario trace in Langfuse (by `engagement_id` / investigation id):

| Check | Pass |
|-------|------|
| Finding has structured fields (not empty blob) | yes |
| SOC sparse: `data_gaps` or low confidence, no invented PIDs | yes |
| Intel: IOC lookup cited tool results | yes |
| Consultant: playbook id from search, not hallucinated | yes |
| No unexpected ERROR observations in 60m window | yes |

```bash
./scripts/k8s/langfuse-benchmark-report.sh --window-min 60
```

Record reviewer + date in [k3s-bottleneck-after-report.md](k3s-bottleneck-after-report.md) § Scenarios.
