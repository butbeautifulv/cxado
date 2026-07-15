# K3s bottleneck baseline (before fixes)

Human-readable snapshot taken **before** Phase 1–9 implementation. Machine-readable source: `deploy/.local/logs/k3s-baseline/baseline-20260709-110423.json` (gitignored).

Related: [k3s-bottleneck-slo.md](k3s-bottleneck-slo.md) | [k3s-cluster-snapshot.md](k3s-cluster-snapshot.md) | [k3s-obs-access.md](k3s-obs-access.md)

## Metadata

| Field | Value |
|-------|-------|
| Collected at | 2026-07-09T11:04:26Z |
| Node IP | `192.168.0.133` (WiFi); cluster node `bbv-p30-k44` @ `10.8.185.15` |
| Prometheus | `https://192.168.0.133:30091` |
| Snapshot query id | `baseline-20260709-110423.json` |
| Collector | `./scripts/k8s/collect-k3s-baseline.sh` |

## Scrape targets

Query: `scrape_up`, `scrape_down`

| Job | Up | Notes |
|-----|----|-------|
| egregore-api | 1 | Only egregore scrape surface today |
| egregore-worker | — | **No scrape job** (Phase 1) |
| veil-api | 1 | |
| veil-mcp | 1 | |
| vllm | 1 | `10.8.185.185:11611` |
| prometheus, node-exporter (obs), kube-state-metrics, tempo, loki, grafana | 1 | |
| proxmox-gpu-node | **1** | `10.8.185.185:9100` |
| proxmox-gpu-dcgm | **1** | `10.8.185.185:9400` (nvidia-smi fallback) |
| veil-ingest-worker | **N/A** | Phase 6: scrape **gated off** in graph-only (not down) |
| veil-pipeline-worker | **N/A** | gated off |
| veil-engage-events-worker | **N/A** | gated off |

## Worker jobs (7d)

Queries: `worker_p95_7d`, `worker_avg_7d`, `worker_error_ratio_7d`

| Persona | p95 (s) | Error % | Notes |
|---------|---------|---------|-------|
| soc | **600** | 74.9% | At timeout ceiling |
| intel | 300 | **100%** | Correlates with `ti_search` failures |
| identity | 300 | **100%** | |
| network | 277.5 | **100%** | |
| dfir | 291 | **100%** | |
| purple | 291 | — | Low volume (NaN ratio) |
| consultant | 183 | 75.8% | |
| conductor / hunter / redteam | — | — | Insufficient samples (NaN) |

**Observability debt:** series come from `egregore-api` scrape only; worker pods are not independently scraped.

## Tool health (7d)

Queries: `tool_errors_7d`, `tool_success_7d`, `ti_search_*`

| Tool | Errors | Success | Priority |
|------|--------|---------|----------|
| **ti_search_in_category** | **72** | **0** | Phase 2 blocker |
| investigate_incident | 14 | 20 | Phase 4 SIEM sparse |
| playbook_procedure | 10 | 0 | Phase 2 |
| playbook_for_technique | 8 | 0 | Phase 2 |
| playbook_search | 5 | 39 | |
| playbook_get | 2 | 0 | Phase 2 |
| search_events | 3 | 3 | |

## Platform KPIs

Queries: `hitl_pending`, `investigations_active`, `events_ingested_rate_1h`

| Metric | Value |
|--------|-------|
| HITL pending | 0 |
| Investigations active | 12 |
| Events ingested | see Grafana `egregore-cys-agi` |

## LLM (vLLM, 1h window)

Queries: `vllm_e2e_avg_1h`, `vllm_e2e_p95_1h`, `vllm_ttft_p95_1h`

| Metric | Value |
|--------|-------|
| E2E avg | ~82 s |
| E2E p95 | ~162 s |
| TTFT p95 | ~9.6 s |

GPU correlation unavailable (DCGM down).

## Veil HTTP (7d)

Query: `veil_mcp_p95_7d`

| Service | p95 |
|---------|-----|
| veil-mcp | **~4.8 ms** |

Veil MCP is fast; tool failures are not Veil latency.

## k8s health

Queries: `pending_egregore`, `egregore_restarts_24h`, `node_mem_pct`

| Check | At snapshot | Historical note |
|-------|-------------|-----------------|
| Pending `egregore-*` | **0** | Phase 5: was 2 pending (Insufficient cpu during RS surge); fixed via replicas/HPA/surge |
| Egregore API/worker | 1 API + 2 workers Running on `offline-20260709-p4` | Rollout verify: `verify-egregore-rollout.sh` |
| Worker nodes | `svo-aosint-ps01`, `svo-pntmon-ps01` Ready | Some `node-exporter`/`promtail` ImagePullBackOff on workers |

See [k3s-cluster-snapshot.md](k3s-cluster-snapshot.md) for pod list.

## Sanitizer / RAG

Queries: `sanitizer_blocks_7d`, `rag_retrievals_7d` — not a latency hotspot; see dashboard panels.

## Gaps / observability debt

1. **No `egregore-worker` scrape** — metrics incomplete after worker restart/HPA (Phase 1).
2. **No failure `reason` taxonomy** — only `status=error` (Phase 3).
3. **`ti_search_in_category` 100% error rate** (Phase 2).
4. ~~**GPU telemetry down**~~ — **fixed Phase 7** (`proxmox-gpu-*` up; DCGM via nvidia-smi fallback on phy-gpu-host01).
5. **Veil background workers** — ~~false-red Prometheus targets~~ **fixed Phase 6** (scrape gated; see `veil-workers-offline-profile.md`).

## Veil workers (Phase 6)

- Profile: **`graph-only`** (default P30) — api/mcp up; worker scrape jobs absent
- Decision: [veil-workers-offline-profile.md](veil-workers-offline-profile.md)
- Audit: `./scripts/k8s/audit-veil-workers.sh`
- Enable workers: `k3s-deploy-veil-offline.sh --with-workers-obs`

## Rollout health (Phase 5)

- Diagnosis: [k3s-rollout-pending-diagnosis.md](k3s-rollout-pending-diagnosis.md)
- Capacity: [k3s-capacity-budget.md](k3s-capacity-budget.md)
- Gate: `./scripts/k8s/verify-egregore-rollout.sh`

## GPU telemetry (Phase 7)

- SSOT: [gpu-host-ssot.md](gpu-host-ssot.md) — **10.8.185.185:11611** (vLLM), :9100/:9400 pending install
- Diagnose: `./scripts/k8s/diagnose-gpu-telemetry.sh`
- Install (on GPU VM): `sudo ./scripts/obs/install-gpu-host-exporters.sh`
- Smoke: `./scripts/k8s/smoke-gpu-telemetry.sh`
- Status: `up{job="vllm"}==1`; `up{job=~"proxmox-gpu-.*"}==1`; `DCGM_FI_DEV_GPU_UTIL` via fallback exporter

## Links

| Resource | URL / UID |
|----------|-----------|
| Grafana overview | `https://192.168.0.133:30002/d/cxado-overview` |
| Egregore AGI dashboard | `https://192.168.0.133:30002/d/egregore-cys-agi` |
| Langfuse | `https://192.168.0.133:30001` — project `egregore-dev` |
| Master plan | `.cursor/plans/k3s-bottleneck-fixes_48692291.plan.md` |

## Refresh

```bash
make k3s-baseline
# Update this file from the latest deploy/.local/logs/k3s-baseline/baseline-*.json
```
