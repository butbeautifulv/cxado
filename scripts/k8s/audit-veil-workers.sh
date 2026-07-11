#!/usr/bin/env bash
# Audit Veil worker deployments, Services, and Prometheus profile on k3s offline.
#
# Usage:
#   ./scripts/k8s/audit-veil-workers.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS_VEIL="${VEIL_NS:-veil}"
NS_OBS="${CXADO_OBS_NS:-cxado-obs}"
LOG_DIR="${ROOT}/deploy_logs/k3s-baseline"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/veil-workers-audit-${STAMP}.log"

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

section() { printf '\n========== %s ==========\n' "$1" | tee -a "${LOG_FILE}"; }

{
  section "veil deployments"
  kubectl_cmd get deploy -n "${NS_VEIL}" -o wide 2>/dev/null || true

  section "worker pods"
  kubectl_cmd get pods -n "${NS_VEIL}" -l 'app in (veil-ingest-worker,veil-pipeline-worker,veil-engage-events-worker)' -o wide 2>/dev/null || true

  section "metrics services"
  kubectl_cmd get svc -n "${NS_VEIL}" 2>/dev/null | grep -E 'ingest-worker-metrics|pipeline-worker-metrics|engage-events-worker-metrics|veil-api|veil-mcp' || true

  section "prometheus veil_profile label"
  kubectl_cmd get configmap prometheus-config -n "${NS_OBS}" -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null \
    | grep -E 'veil_profile|veil-ingest-worker|veil-pipeline-worker|veil-engage-events-worker' || echo "(no worker jobs in config — expected for graph-only)"

  section "graph-only expectation"
  echo "graph-only: worker deploy replicas=0, no worker scrape jobs in prometheus-config"
  echo "workers-obs: 3 worker deploys Ready, 3 *-metrics Services, worker jobs in prometheus-config"

} | tee -a "${LOG_FILE}"

echo ""
echo "Log: ${LOG_FILE}"
exit 0
