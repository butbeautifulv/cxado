#!/usr/bin/env bash
# Diagnose GPU host telemetry reachability from k3s offline cluster.
#
# Usage:
#   ./scripts/k8s/diagnose-gpu-telemetry.sh
#   GPU_HOST_IP=10.8.185.185 ./scripts/k8s/diagnose-gpu-telemetry.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

GPU_IP="${GPU_HOST_IP:-10.8.185.185}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
PROMETHEUS_URL="${PROMETHEUS_URL:-https://${CXADO_NODE_IP}:30091}"
PORTS=(11611 9100 9400)

probe() {
  local ip="$1" port="$2"
  if curl -fsS -m 5 -o /dev/null "http://${ip}:${port}/metrics" 2>/dev/null; then
    return 0
  fi
  if [[ -n "${SSH_HOST}" ]]; then
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "curl -fsS -m 5 -o /dev/null 'http://${ip}:${port}/metrics'" 2>/dev/null
    return $?
  fi
  return 1
}

echo "[diagnose] GPU host telemetry (ip=${GPU_IP})"

for port in "${PORTS[@]}"; do
  if probe "${GPU_IP}" "${port}"; then
    echo "OK   :${port}/metrics reachable from k3s node"
  else
    case "${port}" in
      11611) echo "FAIL :${port} — vLLM metrics (critical)" ;;
      9100) echo "FAIL :${port} — node-exporter not running or firewall (install-gpu-host-exporters.sh)" ;;
      9400) echo "FAIL :${port} — dcgm-exporter not running or firewall" ;;
    esac
  fi
done

echo ""
echo "[diagnose] Prometheus targets"
if curl -fsSk -m 10 "${PROMETHEUS_URL}/api/v1/targets" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data.get('data', {}).get('activeTargets', []):
    job = t.get('labels', {}).get('job', '')
    if 'vllm' in job or 'proxmox-gpu' in job:
        print(f\"{job:20} {t.get('health','?'):6} {t.get('lastError','')[:100]}\")
" 2>/dev/null; then
  :
else
  echo "WARN could not query ${PROMETHEUS_URL}/api/v1/targets"
fi

echo ""
echo "SSOT: docs/observability/gpu-host-ssot.md"
