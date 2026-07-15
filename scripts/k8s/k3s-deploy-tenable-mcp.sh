#!/usr/bin/env bash
# Build tenable-mcp image, import into k3s, deploy helm chart with credentials secret.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD-tenable-mcp ./scripts/k8s/k3s-deploy-tenable-mcp.sh
#
# Secrets: deploy/.secrets/tenable-mcp.env (gitignored)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)-tenable-mcp}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
SECRETS_ENV="${ROOT}/deploy/.secrets/tenable-mcp.env"
KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
HELM="KUBECONFIG=/home/bbv/.kube/config helm"

log() { printf '[k3s-deploy-tenable-mcp] %s\n' "$*"; }

if [[ ! -f "${SECRETS_ENV}" ]]; then
  echo "missing ${SECRETS_ENV} — copy from deploy/.secrets/tenable-mcp.env.example" >&2
  exit 2
fi

log "tag=${TAG} ssh=${SSH_HOST}:${SSH_PORT}"

export DOCKER_BUILDKIT=1
log "docker build cxado/tenable-mcp:${TAG}"
docker build \
  -t "cxado/tenable-mcp:${TAG}" \
  -f "${ROOT}/projects/precursor/tenable-mcp/Dockerfile" \
  "${ROOT}/projects/precursor/tenable-mcp"

OUT_TAR="/tmp/cxado_offline_tenable_mcp_${TAG}.tar"
log "docker save -> ${OUT_TAR}"
docker save -o "${OUT_TAR}" "cxado/tenable-mcp:${TAG}"

if command -v rsync >/dev/null 2>&1; then
  rsync -avP -e "ssh -p ${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
else
  scp -P "${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
fi

remote_tar="/tmp/$(basename "${OUT_TAR}")"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
if [[ -n "${SUDO_PW}" ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images import '${remote_tar}'"
else
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
fi

rsync -a -e "ssh -p ${SSH_PORT}" \
  "${ROOT}/projects/precursor/tenable-mcp/deploy/helm/tenable-mcp" \
  "${SSH_HOST}:/tmp/tenable-mcp-helm"

ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} create ns ${NS_APP} 2>/dev/null || true"

log "apply secret tenable-mcp-credentials"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n ${NS_APP} delete secret tenable-mcp-credentials --ignore-not-found"
scp -P "${SSH_PORT}" "${SECRETS_ENV}" "${SSH_HOST}:/tmp/tenable-mcp-credentials.env"
ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n ${NS_APP} create secret generic tenable-mcp-credentials --from-env-file=/tmp/tenable-mcp-credentials.env"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "rm -f /tmp/tenable-mcp-credentials.env"

log "helm upgrade tenable-mcp"
ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${HELM} upgrade --install tenable-mcp /tmp/tenable-mcp-helm/tenable-mcp -n ${NS_APP} \
  --set image.tag='${TAG}' \
  --wait --timeout 5m"

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n ${NS_APP} rollout status deploy/tenable-mcp --timeout=180s"

log "done — service http://tenable-mcp.${NS_APP}.svc.cluster.local:8095/mcp"
