#!/usr/bin/env bash
# Scale CoreDNS to 3 replicas with hostname topology spread (k3s offline 3-node).
#
# Usage:
#   ./scripts/k8s/k3s-coredns-ha.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
REPLICAS="${COREDNS_REPLICAS:-3}"

KCTL="K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl"

log() { printf '[k3s-coredns-ha] %s\n' "$*"; }

log "patch coredns replicas=${REPLICAS} ssh=${SSH_HOST}:${SSH_PORT}"

PATCH_BODY=$(cat <<PATCH
spec:
  replicas: ${REPLICAS}
  revisionHistoryLimit: 3
  template:
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              k8s-app: kube-dns
PATCH
)

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n kube-system patch deployment coredns --type=strategic --patch-file /dev/stdin" <<<"${PATCH_BODY}"

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n kube-system rollout status deploy/coredns --timeout=180s"

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n kube-system get pods -l k8s-app=kube-dns -o wide"

log "done"
