#!/usr/bin/env bash
# Import Langfuse offline images into k3s containerd on the target node.
#
# Usage:
#   source deploy/.secrets/cxado-k3s.env
#   ./scripts/k8s/k3s-offline-bundle-langfuse.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
OUT_TAR="${CXADO_LANGFUSE_TAR:-/tmp/cxado_langfuse_offline_$(date +%Y%m%d).tar}"

log() { printf '[k3s-offline-langfuse] %s\n' "$*"; }

pull_images() {
  docker pull langfuse/langfuse:3
  docker pull langfuse/langfuse-worker:3
  docker pull clickhouse/clickhouse-server:24.8
  docker pull minio/minio:RELEASE.2024-11-07T00-52-20Z
  docker pull minio/mc:latest
  docker pull postgres:17
}

save_bundle() {
  log "docker save -> ${OUT_TAR}"
  docker save -o "${OUT_TAR}" \
    langfuse/langfuse:3 \
    langfuse/langfuse-worker:3 \
    clickhouse/clickhouse-server:24.8 \
    minio/minio:RELEASE.2024-11-07T00-52-20Z \
    minio/mc:latest \
    postgres:17
  ls -lh "${OUT_TAR}"
}

import_remote() {
  scp -P "${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
  local remote_tar="/tmp/$(basename "${OUT_TAR}")"
  if [[ -n "${SUDO_PW}" ]]; then
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images import '${remote_tar}'"
  else
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
  fi
}

main() {
  pull_images
  save_bundle
  import_remote
  log "done"
}

main "$@"
