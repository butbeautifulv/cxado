#!/usr/bin/env bash
# Bootstrap Veil playbook offline bundle onto the k3s node filesystem for hostPath mounts.
#
# Extracts docs/skills-index + corpus under /var/lib/veil/playbooks (full repo layout).
#
# Usage:
#   ./scripts/veil/bootstrap-skills-index-hostpath.sh /path/to/veil_playbooks_offline.tgz
#
# Env:
# - CXADO_OFFLINE_SSH_HOST (default: offline-host)
# - CXADO_OFFLINE_SSH_PORT (default: 22)
# - CXADO_OFFLINE_SUDO_PW  (optional; if omitted expects passwordless sudo)
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/veil_playbooks_offline.tgz" >&2
  exit 2
fi

TGZ="$1"
if [[ ! -f "$TGZ" ]]; then
  echo "file not found: $TGZ" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

REMOTE_TGZ="/tmp/$(basename "$TGZ")"
PLAYBOOKS_ROOT="/var/lib/veil/playbooks"
INDEX_FILE="${PLAYBOOKS_ROOT}/docs/skills-index/cyber-skills.json"
CORPUS_DIR="${PLAYBOOKS_ROOT}/corpus/anthropic-cybersecurity-skills/skills"
BLEVE_DIR="${PLAYBOOKS_ROOT}/docs/skills-index/playbook-search.bleve"

log() { printf '[veil-bootstrap-skills] %s\n' "$*"; }
die() { printf '[veil-bootstrap-skills] ERROR: %s\n' "$*" >&2; exit 1; }

remote_sudo() {
  local cmd="$1"
  if [[ -n "${SUDO_PW}" ]]; then
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' bash -c $(printf '%q' "${cmd}")"
  else
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo bash -c $(printf '%q' "${cmd}")"
  fi
}

log "copy tgz to target: ${REMOTE_TGZ}"
scp -P "${SSH_PORT}" "${TGZ}" "${SSH_HOST}:${REMOTE_TGZ}"

log "extract into hostPath root: ${PLAYBOOKS_ROOT}"
remote_sudo "mkdir -p '${PLAYBOOKS_ROOT}'"
remote_sudo "tar -xzf '${REMOTE_TGZ}' -C '${PLAYBOOKS_ROOT}'"

log "verify bundle artifacts"
remote_sudo "test -f '${INDEX_FILE}'"
remote_sudo "test -d '${BLEVE_DIR}'"
remote_sudo "test -d '${CORPUS_DIR}'"

log "ok:"
log "  ${INDEX_FILE}"
log "  ${BLEVE_DIR}"
log "  ${CORPUS_DIR}"
