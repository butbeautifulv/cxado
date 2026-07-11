#!/usr/bin/env bash
# Build egregore backend image and import into k3s containerd on the target.
# Bundle Next.js UI separately: k3s-offline-bundle-egregore-ui.sh
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-offline-bundle-egregore.sh
#
# Env:
# - CXADO_OFFLINE_SSH_HOST (default: bbv@10.8.184.22)
# - CXADO_OFFLINE_SSH_PORT (default: 22012)
# - CXADO_OFFLINE_SUDO_PW  (optional; if omitted expects passwordless sudo)
# - NEXT_PUBLIC_LANGFUSE_HOST — unused (Next.js UI not bundled)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"

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

log "save -> ${OUT_TAR}"
docker save -o "${OUT_TAR}" "cxado/egregore:${TAG}"
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
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images ls | grep -E 'cxado/egregore' || true"
else
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images ls | grep -E 'cxado/egregore' || true"
fi

log "done"

