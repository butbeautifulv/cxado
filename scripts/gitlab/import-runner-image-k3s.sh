#!/usr/bin/env bash
# Import gitlab-runner (and optional CI images) from local docker into k3s containerd.
#
# Usage:
#   ./scripts/gitlab/import-runner-image-k3s.sh --ssh bbv-p30-wifi
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${1:-}"
RUNNER_IMAGE="${NEXUS_DOCKER_REGISTRY}/gitlab/gitlab-runner:latest"

log() { printf '[import-runner-k3s] %s\n' "$*"; }

run_remote() {
  if [[ "${1:-}" == "--ssh" ]]; then
    SSH_HOST="${2:-bbv-p30-wifi}"
    ssh "${SSH_HOST}" "bash -s" <<EOF
set -euo pipefail
IMG='${RUNNER_IMAGE}'
SUDO_PW='${CXADO_OFFLINE_SUDO_PW:-}'
sudo_run() {
  if [[ -n "\${SUDO_PW}" ]]; then
    printf '%s\n' "\${SUDO_PW}" | sudo -S -p "" "\$@"
  else
    sudo "\$@"
  fi
}
if docker image inspect "\$IMG" >/dev/null 2>&1; then
  TAR="/tmp/cxado-gitlab-runner-\$\$.tar"
  docker save "\$IMG" -o "\$TAR"
  sudo_run k3s ctr images import "\$TAR"
  rm -f "\$TAR"
  echo "imported \$IMG"
  sudo_run k3s ctr images ls | grep gitlab-runner | head -3
else
  echo "missing docker image \$IMG — docker pull first" >&2
  exit 2
fi
EOF
  else
    if docker image inspect "${RUNNER_IMAGE}" >/dev/null 2>&1; then
      docker save "${RUNNER_IMAGE}" | sudo k3s ctr images import -
    else
      echo "missing ${RUNNER_IMAGE}" >&2
      exit 2
    fi
  fi
}

log "import ${RUNNER_IMAGE} into k3s containerd"
run_remote "$@"
