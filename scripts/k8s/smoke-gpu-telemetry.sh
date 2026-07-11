#!/usr/bin/env bash
# Smoke gate for GPU host telemetry (vLLM + node-exporter + DCGM).
#
# Usage:
#   ./scripts/k8s/smoke-gpu-telemetry.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

PROMETHEUS_URL="${PROMETHEUS_URL:-https://${CXADO_NODE_IP}:30091}"
GPU_IP="${GPU_HOST_IP:-10.8.185.185}"

fail=0
ok() { echo "OK  $1"; }
bad() { echo "FAIL $1"; fail=1; }
skip() { echo "SKIP $1"; }

prom_up() {
  local job="$1"
  curl -fsSk -m 10 -G "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=up{job=\"${job}\"} == 1" 2>/dev/null \
    | grep -q '"value":\[.*,"1"\]'
}

prom_has_dcgm() {
  curl -fsSk -m 10 -G "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode 'query=count(DCGM_FI_DEV_GPU_UTIL)' 2>/dev/null \
    | grep -q '"value":\[.*,"[1-9]'
}

echo "=== GPU telemetry smoke ==="

if prom_up "vllm"; then ok "prometheus up{job=vllm}"; else bad "prometheus up{job=vllm}"; fi

if prom_up "proxmox-gpu-node"; then
  ok "prometheus up{job=proxmox-gpu-node}"
else
  bad "prometheus up{job=proxmox-gpu-node} — run install-gpu-host-exporters.sh on ${GPU_IP}"
fi

if prom_up "proxmox-gpu-dcgm"; then
  ok "prometheus up{job=proxmox-gpu-dcgm}"
else
  bad "prometheus up{job=proxmox-gpu-dcgm} — run install-gpu-host-exporters.sh on ${GPU_IP}"
fi

if prom_has_dcgm; then
  ok "DCGM_FI_DEV_GPU_UTIL series present"
else
  skip "DCGM_FI_DEV_GPU_UTIL absent (expected until exporters installed + GPU load)"
fi

if [[ -x "${ROOT}/scripts/k8s/diagnose-gpu-telemetry.sh" ]]; then
  "${ROOT}/scripts/k8s/diagnose-gpu-telemetry.sh" || true
fi

exit "${fail}"
