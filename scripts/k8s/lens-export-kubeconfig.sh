#!/usr/bin/env bash
# Export P30 k3s kubeconfig for Lens / kubectl on the laptop (gitignored output).
#
# Usage:
#   ./scripts/k8s/lens-export-kubeconfig.sh
#   ./scripts/k8s/lens-export-kubeconfig.sh --with-tunnel
#
# Output: deploy/.secrets/kubeconfig-cxado-p30.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${ROOT}/deploy/.secrets/kubeconfig-cxado-p30.yaml"
LOCAL_PORT="${CXADO_LENS_LOCAL_PORT:-16443}"
CLUSTER_NAME="${CXADO_LENS_CLUSTER_NAME:-cxado-p30}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"

WITH_TUNNEL=false
[[ "${1:-}" == "--with-tunnel" ]] && WITH_TUNNEL=true

if [[ "${WITH_TUNNEL}" == true ]]; then
  "${ROOT}/scripts/k8s/lens-tunnel.sh" start
fi

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

ssh "${SSH_HOST}" 'cat ~/.kube/config 2>/dev/null || sudo cat /etc/rancher/k3s/k3s.yaml' >"${TMP}"

sed \
  -e "s|server: https://[^[:space:]]*|server: https://127.0.0.1:${LOCAL_PORT}|" \
  -e "s|cluster: default|cluster: ${CLUSTER_NAME}|g" \
  -e "s|user: default|user: ${CLUSTER_NAME}|g" \
  -e "s|current-context: default|current-context: ${CLUSTER_NAME}|g" \
  -e "s|name: default|name: ${CLUSTER_NAME}|g" \
  "${TMP}" >"${OUT}"

chmod 600 "${OUT}"

if KUBECONFIG="${OUT}" kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
  echo "ok: kubectl via ${OUT}"
else
  echo "warn: kubectl check failed — is tunnel up? ./scripts/k8s/lens-tunnel.sh start" >&2
fi

echo "wrote ${OUT}"
echo "Lens: Catalog → + → Add from kubeconfig → ${OUT}"
