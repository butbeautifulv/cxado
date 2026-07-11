#!/usr/bin/env bash
# Stop DefectDojo rootless container on VM_01 after k3s migration.
#
# Usage:
#   ./scripts/k8s/defectdojo-vm01-decommission.sh
#   ./scripts/k8s/defectdojo-vm01-decommission.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

SSH_JUMP="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
VM_HOST="${VM_01_IP:-10.20.16.195}"
VM_USER="${VM_01_USER:-astradmin}"
DRY_RUN=false

log() { printf '[defectdojo-vm01-decommission] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

CMD='podman ps --format "{{.Names}}" | grep -i defect || true; \
  podman stop $(podman ps -q --filter publish=8080) 2>/dev/null || true; \
  podman ps --filter publish=8080'

if [[ "${DRY_RUN}" == true ]]; then
  log "[dry-run] would run on ${VM_HOST}: ${CMD}"
  exit 0
fi

log "stop DefectDojo containers on ${VM_HOST}"
ssh -o ProxyJump="${SSH_JUMP}" "${VM_USER}@${VM_HOST}" bash -lc "${CMD}" || true
log "done — verify: ss -tlnp | grep 8080 should be empty on VM_01"
