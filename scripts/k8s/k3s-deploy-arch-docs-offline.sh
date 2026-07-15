#!/usr/bin/env bash
# Deploy architecture docs site on offline k3s (hostPath + nginx).
#
# Usage (from laptop; SSH forward to k3s node):
#   ./scripts/k8s/k3s-deploy-arch-docs-offline.sh
#   ./scripts/k8s/k3s-deploy-arch-docs-offline.sh --skip-bundle
#
# On k3s node directly (no SSH):
#   ./scripts/k8s/k3s-deploy-arch-docs-offline.sh --local
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
K8S_DIR="${ROOT}/deploy/k8s/arch-docs-offline"
TLS_DIR="${ROOT}/deploy/k8s/offline-tls"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
KCTL="${KUBECTL:-KUBECONFIG=/home/bbv/.kube/config k3s kubectl}"

LOCAL=0
SKIP_BUNDLE=0

for arg in "$@"; do
  case "$arg" in
    --local) LOCAL=1 ;;
    --skip-bundle) SKIP_BUNDLE=1 ;;
  esac
done

log() { printf '[arch-docs-deploy] %s\n' "$*"; }

apply() {
  local manifest="$1"
  if [[ "${LOCAL}" -eq 1 ]]; then
    eval "${KCTL} apply -f '${manifest}'"
  else
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} apply -f -" < "${manifest}"
  fi
}

kctl() {
  if [[ "${LOCAL}" -eq 1 ]]; then
    eval "${KCTL} $*"
  else
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} $*"
  fi
}

if [[ "${SKIP_BUNDLE}" -eq 0 ]]; then
  BUNDLE_ARGS=()
  [[ "${LOCAL}" -eq 0 ]] && BUNDLE_ARGS+=(--remote)
  "${ROOT}/scripts/k8s/rsync-arch-docs-site.sh" "${BUNDLE_ARGS[@]}"
fi

log "apply arch-docs manifests"
apply "${K8S_DIR}/11-nginx-config.yaml"
apply "${K8S_DIR}/10-deployment.yaml"
apply "${K8S_DIR}/12-service.yaml"

log "apply TLS gateway updates (port 30080)"
apply "${TLS_DIR}/10-nginx-config.yaml"
apply "${TLS_DIR}/20-gateway.yaml"

log "rollout arch-docs + tls gateway"
kctl -n cxado-edge rollout restart deployment/cxado-arch-docs 2>/dev/null || kctl -n cxado-edge apply -f "${K8S_DIR}/10-deployment.yaml"
kctl -n cxado-edge rollout status deployment/cxado-arch-docs --timeout=120s
kctl -n cxado-edge rollout restart deployment/cxado-tls-gateway
kctl -n cxado-edge rollout status deployment/cxado-tls-gateway --timeout=120s

NODE_IP="${CXADO_NODE_IP}"
log "done — site at https://${NODE_IP}:30080"
