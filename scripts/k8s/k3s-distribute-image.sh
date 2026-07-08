#!/usr/bin/env bash
# Import a docker archive into k3s containerd on P30 and worker nodes.
#
# Usage:
#   ./scripts/k8s/k3s-distribute-image.sh /tmp/cxado_egregore_TAG.tar
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

TAR="${1:-}"
if [[ -z "${TAR}" || ! -f "${TAR}" ]]; then
  echo "usage: $0 <image.tar>" >&2
  exit 2
fi

SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
BASENAME="$(basename "${TAR}")"

log() { printf '[k3s-distribute-image] %s\n' "$*"; }

import_on() {
  local target="$1" user="$2" pw="${3:-}"
  local dest="${user}@${target}"

  log "copy -> ${dest}"
  if ! scp -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "${TAR}" "${dest}:/tmp/${BASENAME}"; then
    log "WARN: scp failed for ${dest} — skipping"
    return 0
  fi

  log "import on ${dest}"
  if [[ -n "${pw}" ]]; then
    if ! ssh -o ConnectTimeout=10 "${dest}" "printf '%s\n' '${pw}' | sudo -S -p '' k3s ctr images import '/tmp/${BASENAME}'"; then
      log "WARN: import failed on ${dest}"
    fi
  else
    ssh -o ConnectTimeout=10 "${dest}" "sudo k3s ctr images import '/tmp/${BASENAME}'" || log "WARN: import failed on ${dest}"
  fi
}

# P30 control-plane (local when CI runs on runner host)
if [[ -f "${TAR}" ]]; then
  if [[ -n "${SUDO_PW}" ]]; then
    printf '%s\n' "${SUDO_PW}" | sudo -S -p "" k3s ctr images import "${TAR}"
  else
    sudo k3s ctr images import "${TAR}"
  fi
fi

# Workers via ProxyJump through P30
import_on "10.20.16.195" "astradmin" "${VM_01_PWD:-}"
import_on "10.20.16.185" "admin" "${VM_02_PWD:-}"

log "done"
