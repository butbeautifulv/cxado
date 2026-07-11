#!/usr/bin/env bash
# Diagnose Pending egregore pods and capacity pressure on k3s offline.
#
# Usage:
#   ./scripts/k8s/diagnose-pending-pods.sh
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/diagnose-pending-pods.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS="${CXADO_APP_NS:-cxado-app}"
LOG_DIR="${ROOT}/deploy_logs/k3s-baseline"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/pending-diagnosis-${STAMP}.log"

mkdir -p "${LOG_DIR}"

kubectl_cmd() {
  if [[ -n "${SSH_HOST}" ]]; then
    # shellcheck disable=SC2029
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
  else
    kubectl "$@"
  fi
}

section() {
  printf '\n========== %s ==========\n' "$1" | tee -a "${LOG_FILE}"
}

{
  section "egregore pods"
  kubectl_cmd get pods -n "${NS}" -l 'app in (egregore-api,egregore-worker,egregore-ui)' -o wide

  section "all Pending pods in ${NS}"
  kubectl_cmd get pods -n "${NS}" --field-selector=status.phase=Pending -o wide || true

  section "Pending egregore describe (Events)"
  while read -r pod; do
    [[ -z "${pod}" ]] && continue
    printf '\n--- %s ---\n' "${pod}"
    kubectl_cmd describe -n "${NS}" "${pod}" | sed -n '/Events:/,$p'
  done < <(kubectl_cmd get pods -n "${NS}" --field-selector=status.phase=Pending \
    -l 'app in (egregore-api,egregore-worker,egregore-ui)' -o name 2>/dev/null || true)

  section "resource quota"
  kubectl_cmd describe resourcequota -n "${NS}" || true

  section "limit range"
  kubectl_cmd describe limitrange -n "${NS}" || true

  section "egregore deployments"
  kubectl_cmd get deploy -n "${NS}" egregore-api egregore-worker egregore-ui 2>/dev/null || true

  section "HPA"
  kubectl_cmd get hpa -n "${NS}" 2>/dev/null || true

  section "egregore ReplicaSets"
  kubectl_cmd get rs -n "${NS}" -l 'app in (egregore-api,egregore-worker)' -o wide 2>/dev/null || true

  section "node allocatable"
  kubectl_cmd get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory

  section "cxado-app scheduled CPU requests (sum)"
  kubectl_cmd get pods -n "${NS}" -o json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
total_cpu = 0
total_mem = 0
for item in data.get('items', []):
    if not item.get('spec', {}).get('nodeName'):
        continue
    for c in item.get('spec', {}).get('containers', []):
        req = c.get('resources', {}).get('requests', {})
        cpu = req.get('cpu', '0')
        mem = req.get('memory', '0')
        if cpu.endswith('m'):
            total_cpu += int(cpu[:-1])
        elif cpu.replace('.', '', 1).isdigit():
            total_cpu += int(float(cpu) * 1000)
        if mem.endswith('Mi'):
            total_mem += int(mem[:-2])
        elif mem.endswith('Gi'):
            total_mem += int(float(mem[:-2]) * 1024)
print(f'requests.cpu (scheduled in {sys.argv[1]}): {total_cpu}m')
print(f'requests.memory (scheduled in {sys.argv[1]}): {total_mem}Mi')
" "${NS}" 2>/dev/null || echo "could not sum requests"

  section "non-Running egregore (ImagePullBackOff / CrashLoop)"
  kubectl_cmd get pods -n "${NS}" -l 'app in (egregore-api,egregore-worker,egregore-ui)' \
    --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide 2>/dev/null || true

} | tee -a "${LOG_FILE}"

echo ""
echo "Log: ${LOG_FILE}"
