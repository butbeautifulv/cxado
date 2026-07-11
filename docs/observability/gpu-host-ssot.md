# GPU Host SSOT — phy-gpu-host01

**Phase:** 7 (P7.1)  
**Canonical host:** `10.8.185.185` (`phy-gpu-host01`)  
**k3s scraper:** P30 `10.8.185.15` (corp NAT) / `192.168.0.133` (WiFi)

## Endpoint table (verified 2026-07-09 from P30)

| Role | IP | Port | Path | From P30 | Notes |
|------|-----|------|------|----------|-------|
| vLLM OpenAI API | 10.8.185.185 | **11611** | `/v1` | OK | egregore `LLM_BASE_URL` |
| vLLM Prometheus | 10.8.185.185 | **11611** | `/metrics` | OK | `up{job="vllm"}==1` |
| node-exporter | 10.8.185.185 | **9100** | `/metrics` | OK | docker `proxmox-node-exporter` |
| dcgm-exporter | 10.8.185.185 | **9400** | `/metrics` | OK | systemd `gpu-metrics-exporter` (nvidia-smi fallback) |

### Deprecated / unreachable from P30

| IP | Status | Action |
|----|--------|--------|
| `10.8.185.186` | timeout / refused on all ports | remove from docs; was stale SSOT |

## Prometheus jobs (`prometheus-k3s.yml`)

| job_name | target | `instance` label |
|----------|--------|------------------|
| `vllm` | `10.8.185.185:11611` | (scrape address) + `host=phy-gpu-host01` |
| `proxmox-gpu-node` | `10.8.185.185:9100` | `phy-gpu-host01` |
| `proxmox-gpu-dcgm` | `10.8.185.185:9400` | `phy-gpu-host01` |

## Install exporters (GPU VM — manual)

**Access:** `phy-gpu-host01` is a Proxmox node (`10.8.185.185:8006`). SSH works from P30 (`10.8.185.15`); from dev LAN use Proxmox UI or hop via P30. Auth: `root@pam` (credentials in team vault, not in git).

Run **on phy-gpu-host01** (console, SSH from P30, or Proxmox shell):

```bash
sudo ./scripts/obs/install-gpu-host-exporters.sh
```

If `nvidia-container-toolkit` is missing, the install script falls back to `gpu-metrics-exporter-fallback.py` (systemd on `:9400`, `nvidia-smi` → DCGM-compatible metrics).

Verify locally on GPU VM:

```bash
curl -fsS localhost:9100/metrics | head -3
curl -fsS localhost:9400/metrics | grep DCGM_FI_DEV_GPU_UTIL
```

Verify from P30:

```bash
./scripts/k8s/diagnose-gpu-telemetry.sh
./scripts/k8s/smoke-gpu-telemetry.sh
```

## Network (P7.4)

Allow **from** `10.8.185.15/32` (k3s node corp IP) **to** GPU VM:

| Port | Service |
|------|---------|
| 11611 | vLLM (already works) |
| 9100 | node-exporter |
| 9400 | dcgm-exporter |

On GPU VM:

```bash
ss -lntp | grep -E '9100|9400|11611'
# ufw example:
# ufw allow from 10.8.185.15 to any port 9100 proto tcp
# ufw allow from 10.8.185.15 to any port 9400 proto tcp
```

## Correlation runbook

- **vLLM p95 up + GPU util > 85%** → GPU saturation; tune Phase 8 concurrency before scaling hardware.
- **vLLM p95 up + GPU util low** → worker/agent loops or queue (`vllm:num_requests_waiting`); see Phase 4.
- **vLLM up + DCGM down** → install exporters (this phase); alert `VLLMUpButGPUTelemetryDown`.

## Repo files using this SSOT

| File | Field |
|------|-------|
| `deploy/k8s/obs-offline/prometheus-k3s.yml` | scrape targets |
| `deploy/k8s/cxado-offline/values-egregore-offline.yaml` | `llm.baseUrl` |
| `docs/deploy/k3s-offline-baseline.md` | monitoring table |
| `deploy/ports.md` | GPU host ports |
| `scripts/obs/install-gpu-host-exporters.sh` | install |
