#!/usr/bin/env bash
# Apply TLS gateway (nginx) for offline NodePorts and remove plain-HTTP nodeport services.
#
# Usage:
#   ./scripts/k8s/offline-tls-apply.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"

apply_remote() {
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} apply -f -" < "$1"
}

delete_remote() {
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} delete -f - --ignore-not-found" < "$1"
}

NODE_IP="${CXADO_NODE_IP}"
NODE_HOSTNAME="${CXADO_NODE_HOSTNAME:-bbv-p30-k44}"

echo "[offline-tls] generating tls cert (SAN includes ${NODE_IP}, ${NODE_HOSTNAME})"
CXADO_NODE_IP="${NODE_IP}" CXADO_NODE_HOSTNAME="${NODE_HOSTNAME}" \
  "${ROOT}/scripts/k8s/offline-tls-create-secret.sh" --certs-only --force

TLS_DIR="${CXADO_TLS_DIR:-${ROOT}/deploy/.secrets/tls}"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} get ns cxado-edge >/dev/null 2>&1 || ${KCTL} create ns cxado-edge"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-edge delete secret cxado-offline-tls >/dev/null 2>&1 || true"
scp -P "${SSH_PORT}" "${TLS_DIR}/tls.crt" "${TLS_DIR}/tls.key" "${SSH_HOST}:/tmp/"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-edge create secret tls cxado-offline-tls --cert=/tmp/tls.crt --key=/tmp/tls.key"

echo "[offline-tls] removing plain-http nodeport services"
delete_remote "${ROOT}/deploy/k8s/offline-nodeports/00-nodeports.yaml"

echo "[offline-tls] applying tls gateway"
apply_remote "${ROOT}/deploy/k8s/offline-tls/00-namespace.yaml"
apply_remote "${ROOT}/deploy/k8s/offline-tls/10-nginx-config.yaml"
apply_remote "${ROOT}/deploy/k8s/offline-tls/20-gateway.yaml"

echo "[offline-tls] restarting tls gateway + grafana"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-edge rollout restart deploy/cxado-tls-gateway"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-obs rollout restart deploy/grafana"

echo "[offline-tls] done"
echo ""
echo "LAN (any host in corp network):"
echo "  https://${NODE_IP}:30300   egregore-ui   (http auto-redirects)"
echo "  https://${NODE_IP}:30880   egregore-api"
echo "  https://${NODE_IP}:30990   veil-api"
echo "  https://${NODE_IP}:30991   veil-mcp"
echo "  https://${NODE_IP}:30474   neo4j"
echo "  https://${NODE_IP}:30002   grafana"
echo "  https://${NODE_IP}:30091   prometheus"
echo "  https://${NODE_IP}:30001   langfuse"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-edge get pods,svc -o wide"
