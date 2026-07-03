#!/usr/bin/env bash
# Pull and import observability images into k3s containerd on the target node.
#
# Usage:
#   ./scripts/k8s/k3s-offline-bundle-obs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

OUT_TAR="${CXADO_OFFLINE_OBS_TAR:-/tmp/cxado_offline_obs.tar}"

log() { printf '[k3s-offline-obs] %s\n' "$*"; }

pull_images() {
  log "pull prom/prometheus:v3.2.1"
  docker pull prom/prometheus:v3.2.1

  log "pull grafana/grafana:11.5.2"
  docker pull grafana/grafana:11.5.2

  log "pull grafana/tempo:2.7.1"
  docker pull grafana/tempo:2.7.1

  log "pull grafana/loki:3.4.2"
  docker pull grafana/loki:3.4.2

  log "pull grafana/promtail:3.4.2"
  docker pull grafana/promtail:3.4.2
}

save_bundle() {
  log "docker save -> ${OUT_TAR}"
  docker save -o "${OUT_TAR}" \
    prom/prometheus:v3.2.1 \
    grafana/grafana:11.5.2 \
    grafana/tempo:2.7.1 \
    grafana/loki:3.4.2 \
    grafana/promtail:3.4.2
  ls -lh "${OUT_TAR}"
}

transfer_and_import() {
  log "transfer bundle to target"
  if command -v rsync >/dev/null 2>&1; then
    rsync -avP -e "ssh -p ${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
  else
    scp -P "${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
  fi

  local remote_tar="/tmp/$(basename "${OUT_TAR}")"
  log "import into k3s containerd on target: ${remote_tar}"
  if [[ -n "${SUDO_PW}" ]]; then
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images import '${remote_tar}'"
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images ls | grep -E 'prometheus|grafana|loki|tempo|promtail' || true"
  else
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images ls | grep -E 'prometheus|grafana|loki|tempo|promtail' || true"
  fi
}

main() {
  log "ROOT=${ROOT}"
  pull_images
  save_bundle
  transfer_and_import
  log "done"
}

main "$@"
