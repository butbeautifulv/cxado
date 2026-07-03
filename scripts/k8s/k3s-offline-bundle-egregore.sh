#!/usr/bin/env bash
# Build egregore images and import into k3s containerd on the target.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-offline-bundle-egregore.sh
#
# Env:
# - CXADO_OFFLINE_SSH_HOST (default: bbv@10.8.184.22)
# - CXADO_OFFLINE_SSH_PORT (default: 22012)
# - CXADO_OFFLINE_SUDO_PW  (optional; if omitted expects passwordless sudo)
# - NEXT_PUBLIC_LANGFUSE_HOST (default: https://localhost:3001 for SSH tunnel)
#   LAN direct access: NEXT_PUBLIC_LANGFUSE_HOST=https://10.8.185.15:30001
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"
LANGFUSE_HOST="${NEXT_PUBLIC_LANGFUSE_HOST:-https://localhost:3001}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

OUT_TAR="${CXADO_OFFLINE_TAR:-/tmp/cxado_offline_egregore_${TAG}.tar}"

log() { printf '[k3s-offline-egregore] %s\n' "$*"; }

export DOCKER_BUILDKIT=1
CACHE_TAG="${CXADO_OFFLINE_CACHE_TAG:-cache}"

log "build cxado/egregore:${TAG}"
docker build \
  --cache-from "cxado/egregore:${CACHE_TAG}" \
  -t "cxado/egregore:${TAG}" \
  -t "cxado/egregore:${CACHE_TAG}" \
  -f "${ROOT}/projects/egregore/Dockerfile" \
  "${ROOT}/projects/egregore"

log "build cxado/egregore-ui:${TAG} (LANGFUSE_HOST=${LANGFUSE_HOST})"
docker build \
  --build-arg "NEXT_PUBLIC_LANGFUSE_HOST=${LANGFUSE_HOST}" \
  --cache-from "cxado/egregore-ui:${CACHE_TAG}" \
  -t "cxado/egregore-ui:${TAG}" \
  -t "cxado/egregore-ui:${CACHE_TAG}" \
  -f "${ROOT}/projects/egregore/ui/Dockerfile" \
  "${ROOT}/projects/egregore/ui"

log "save -> ${OUT_TAR}"
docker save -o "${OUT_TAR}" "cxado/egregore:${TAG}" "cxado/egregore-ui:${TAG}"
ls -lh "${OUT_TAR}"

log "transfer bundle to target"
if command -v rsync >/dev/null 2>&1; then
  rsync -avP -e "ssh -p ${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
else
  scp -P "${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
fi

remote_tar="/tmp/$(basename "${OUT_TAR}")"
log "import into k3s containerd: ${remote_tar}"
if [[ -n "${SUDO_PW}" ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images import '${remote_tar}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images ls | grep -E 'cxado/egregore|cxado/egregore-ui' || true"
else
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images ls | grep -E 'cxado/egregore|cxado/egregore-ui' || true"
fi

log "done"

