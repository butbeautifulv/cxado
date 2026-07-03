#!/usr/bin/env bash
# Build a minimal offline image bundle and import it into k3s containerd on the target.
# Target access: ssh/scp to the forwarded endpoint (10.8.184.22:22012 -> 10.8.185.15).
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-offline-bundle-min.sh
#
# Requirements (laptop):
# - docker
# - ssh/scp access to target (key-based recommended)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"

# SSH hop (forwarded)
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"

# sudo password on target (optional; if omitted, expects passwordless sudo)
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

OUT_TAR="${CXADO_OFFLINE_TAR:-/tmp/cxado_offline_min_${TAG}.tar}"

log() { printf '[k3s-offline-min] %s\n' "$*"; }

build_local_images() {
  log "build veil-api:${TAG}"
  docker build -t "veil-api:${TAG}" \
    -f "${ROOT}/projects/veil/deploy/knowledge/docker/api.Dockerfile" \
    "${ROOT}/projects/veil"

  log "build veil-mcp:${TAG}"
  docker build -t "veil-mcp:${TAG}" \
    -f "${ROOT}/projects/veil/deploy/knowledge/docker/mcp.Dockerfile" \
    "${ROOT}/projects/veil"
}

pull_external_images() {
  log "pull nats:2.10-alpine"
  docker pull nats:2.10-alpine

  log "pull neo4j:5.26.0"
  docker pull neo4j:5.26.0

  # observability (host/k3s baseline)
  log "pull prom/node-exporter:v1.9.1"
  docker pull prom/node-exporter:v1.9.1
  log "pull registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0"
  docker pull registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0

  log "pull nginx:1.27-alpine (tls gateway)"
  docker pull nginx:1.27-alpine

  # toolbox for offline smoke / debugging
  log "pull curlimages/curl:8.5.0 (toolbox)"
  docker pull curlimages/curl:8.5.0
  log "pull busybox:1.36 (toolbox)"
  docker pull busybox:1.36

  log "pull redpanda (kafka offline)"
  docker pull docker.redpanda.com/redpandadata/redpanda:v24.2.4
}

save_bundle() {
  log "docker save -> ${OUT_TAR}"
  docker save -o "${OUT_TAR}" \
    "veil-api:${TAG}" \
    "veil-mcp:${TAG}" \
    "nats:2.10-alpine" \
    "neo4j:5.26.0" \
    "prom/node-exporter:v1.9.1" \
    "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0" \
    "nginx:1.27-alpine" \
    "curlimages/curl:8.5.0" \
    "busybox:1.36" \
    "docker.redpanda.com/redpandadata/redpanda:v24.2.4"
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
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images ls | grep -E 'veil-|neo4j|nats' || true"
  else
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images ls | grep -E 'veil-|neo4j|nats' || true"
  fi
}

main() {
  log "TAG=${TAG}"
  build_local_images
  pull_external_images
  save_bundle
  transfer_and_import
  log "done"
}

main \"$@\"

