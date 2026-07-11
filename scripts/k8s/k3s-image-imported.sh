#!/usr/bin/env bash
# Return 0 if an image ref is present in k3s containerd on the offline target node.
#
# Usage:
#   ./scripts/k8s/k3s-image-imported.sh cxado/egregore:offline-20260709-p4
#   ./scripts/k8s/k3s-image-imported.sh cxado/egregore-ui:offline-20260709-p4
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

IMAGE_REF="${1:-}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

if [[ -z "${IMAGE_REF}" ]]; then
  echo "usage: $0 <repository:tag>" >&2
  exit 2
fi

repo="${IMAGE_REF%%:*}"
tag="${IMAGE_REF#*:}"
if [[ -z "${repo}" || -z "${tag}" || "${repo}" == "${IMAGE_REF}" ]]; then
  echo "expected repository:tag, got: ${IMAGE_REF}" >&2
  exit 2
fi

ctr_ls() {
  if [[ -n "${SSH_HOST}" ]]; then
    if [[ -n "${SUDO_PW}" ]]; then
      # shellcheck disable=SC2029
      ssh -p "${SSH_PORT}" "${SSH_HOST}" \
        "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images ls -q"
    else
      ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images ls -q"
    fi
  else
    sudo k3s ctr images ls -q
  fi
}

# ctr may list docker.io/cxado/egregore:tag or cxado/egregore:tag
if ctr_ls | grep -qF "${repo}:${tag}"; then
  exit 0
fi
if ctr_ls | grep -qF "docker.io/${repo}:${tag}"; then
  exit 0
fi

echo "image not imported in k3s containerd: ${IMAGE_REF}" >&2
exit 1
