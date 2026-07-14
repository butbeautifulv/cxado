#!/usr/bin/env bash
# Import a docker archive into k3s containerd on P30 and worker nodes.
#
# Offline cluster has no registry pull — images must exist on every node that can
# schedule pods. Bundle scripts import on P30 only; run this after bundle:
#
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-offline-bundle-egregore.sh
#   ./scripts/k8s/k3s-distribute-image.sh /tmp/cxado_offline_egregore_${TAG}.tar
#
# Usage:
#   ./scripts/k8s/k3s-distribute-image.sh /tmp/cxado_egregore_TAG.tar
#   ./scripts/k8s/k3s-distribute-image.sh --workers-only /tmp/cxado_egregore_TAG.tar
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

WORKERS_ONLY=0
if [[ "${1:-}" == "--workers-only" ]]; then
  WORKERS_ONLY=1
  shift
fi

TAR="${1:-}"
if [[ -z "${TAR}" || ! -f "${TAR}" ]]; then
  echo "usage: $0 [--workers-only] <image.tar>" >&2
  exit 2
fi

SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT:-22}"
BASENAME="$(basename "${TAR}")"

log() { printf '[k3s-distribute-image] %s\n' "$*"; }
die() { printf '[k3s-distribute-image] ERROR: %s\n' "$*" >&2; exit 1; }

# Remote shell: SUDO_PW must expand on the target (double quotes, not single).
k3s_import_cmd() {
  local tar_path="$1"
  cat <<EOF
K3S=\$(command -v k3s 2>/dev/null || echo /usr/local/bin/k3s)
if [[ -n "\${SUDO_PW:-}" ]]; then
  printf '%s\n' "\${SUDO_PW}" | sudo -S -p '' "\${K3S}" ctr images import '${tar_path}'
else
  sudo "\${K3S}" ctr images import '${tar_path}'
fi
EOF
}

_copy_to_remote() {
  local dest="$1"
  if command -v rsync >/dev/null 2>&1; then
    rsync -avP --info=progress2 -e "ssh -p ${SSH_PORT} -o ConnectTimeout=20" "${TAR}" "${dest}"
  else
    scp -P "${SSH_PORT}" -o ConnectTimeout=20 "${TAR}" "${dest}"
  fi
}

import_on_p30() {
  local remote_tar="/tmp/${BASENAME}"
  log "copy -> ${SSH_HOST}:${remote_tar}"
  _copy_to_remote "${SSH_HOST}:${remote_tar}"
  log "import on ${SSH_HOST}"
  # shellcheck disable=SC2029
  ssh -p "${SSH_PORT}" -o ConnectTimeout=20 "${SSH_HOST}" \
    "SUDO_PW='${SUDO_PW}' $(k3s_import_cmd "${remote_tar}")"
}

import_on_worker() {
  local target="$1" user="$2" pw="${3:-}"
  local dest="${user}@${target}"
  local jump=(-o "ProxyJump=${SSH_HOST}")

  log "copy -> ${dest}"
  # Worker VMs often lack rsync; scp via ProxyJump is the reliable path.
  scp "${jump[@]}" -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new \
    "${TAR}" "${dest}:/tmp/${BASENAME}"

  log "import on ${dest}"
  # shellcheck disable=SC2029
  ssh "${jump[@]}" -o ConnectTimeout=20 "${dest}" \
    "SUDO_PW='${pw}' $(k3s_import_cmd "/tmp/${BASENAME}")"
}

if [[ "${WORKERS_ONLY}" -eq 0 ]]; then
  if [[ -n "${SSH_HOST}" ]] && ssh -p "${SSH_PORT}" -o ConnectTimeout=5 "${SSH_HOST}" true 2>/dev/null; then
    import_on_p30
  else
    if [[ -n "${SUDO_PW}" ]]; then
      printf '%s\n' "${SUDO_PW}" | sudo -S -p "" k3s ctr images import "${TAR}"
    else
      sudo k3s ctr images import "${TAR}"
    fi
  fi
else
  log "skip P30 import (--workers-only; bundle already imported on control plane)"
fi

if [[ -z "${VM_01_PWD:-}" || -z "${VM_02_PWD:-}" ]]; then
  die "VM_01_PWD / VM_02_PWD unset — worker import required (set in deploy/.secrets/cxado-k3s.env)"
fi

import_on_worker "10.20.16.195" "astradmin" "${VM_01_PWD}"
import_on_worker "10.20.16.185" "admin" "${VM_02_PWD}"

log "done"
