#!/usr/bin/env bash
# Import Redpanda image into offline k3s (airgap — registry TLS fails on node).
#
# Usage:
#   ./scripts/k8s/k3s-offline-bundle-redpanda.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

IMAGE="${REDPANDA_IMAGE:-docker.redpanda.com/redpandadata/redpanda:v24.2.4}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
OUT_TAR="${CXADO_OFFLINE_REDPANDA_TAR:-/tmp/redpanda_offline.tar}"

log() { printf '[k3s-offline-redpanda] %s\n' "$*"; }

log "pull ${IMAGE}"
docker pull "${IMAGE}"

log "save -> ${OUT_TAR}"
docker save -o "${OUT_TAR}" "${IMAGE}"
ls -lh "${OUT_TAR}"

log "transfer to ${SSH_HOST}"
rsync -avP -e "ssh -p ${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"

remote_tar="/tmp/$(basename "${OUT_TAR}")"
log "import into k3s containerd"
if [[ -n "${SUDO_PW}" ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images import '${remote_tar}'"
else
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
fi

log "done"
