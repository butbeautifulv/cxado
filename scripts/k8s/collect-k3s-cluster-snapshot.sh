#!/usr/bin/env bash
# Collect kubectl cluster snapshot for k3s offline (via SSH).
#
# Usage:
#   ./scripts/k8s/collect-k3s-cluster-snapshot.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

OUT_DIR="${ROOT}/deploy_logs/k3s-baseline"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_FILE="${OUT_DIR}/cluster-${STAMP}.txt"

SSH_OPTS=(-p "${CXADO_OFFLINE_SSH_PORT}")
KUBECTL="K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl"

log() { printf '[collect-k3s-cluster-snapshot] %s\n' "$*"; }

mkdir -p "${OUT_DIR}"

run_remote() {
  ssh "${SSH_OPTS[@]}" "${CXADO_OFFLINE_SSH_HOST}" "$@"
}

{
  echo "# k3s cluster snapshot"
  echo "# collected_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# host: ${CXADO_OFFLINE_SSH_HOST}"
  echo "# cxado_node_ip: ${CXADO_NODE_IP}"
  echo
  echo "== nodes =="
  run_remote "${KUBECTL} get nodes -o wide" || true
  echo
  echo "== cxado-app pods =="
  run_remote "${KUBECTL} get pods -n cxado-app -o wide" || true
  echo
  echo "== veil / obs pods =="
  run_remote "${KUBECTL} get pods -A -o wide | grep -E 'cxado-obs|veil'" || true
  echo
  echo "== pending egregore =="
  run_remote "${KUBECTL} get pods -n cxado-app --field-selector=status.phase=Pending -o wide" || true
  echo
  echo "== top pods cxado-app =="
  run_remote "${KUBECTL} top pods -n cxado-app 2>/dev/null" || echo "(metrics-server unavailable)"
  echo
  echo "== recent events cxado-app =="
  run_remote "${KUBECTL} get events -n cxado-app --sort-by='.lastTimestamp' | tail -15" || true
} >"${OUT_FILE}"

log "Wrote ${OUT_FILE}"
