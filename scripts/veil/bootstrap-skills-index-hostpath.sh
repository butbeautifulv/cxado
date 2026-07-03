#!/usr/bin/env bash
# Bootstrap Veil skills-index onto the k3s node filesystem for hostPath mounts.
#
# This is the "variant A" approach: single-node, simple, offline-friendly.
#
# Usage:
#   ./scripts/veil/bootstrap-skills-index-hostpath.sh /path/to/veil_skills_index.tgz
#
# Env:
# - CXADO_OFFLINE_SSH_HOST (default: bbv@0.0.0.0)
# - CXADO_OFFLINE_SSH_PORT (default: 22012)
# - CXADO_OFFLINE_SUDO_PW  (optional; if omitted expects passwordless sudo)
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/veil_skills_index.tgz" >&2
  exit 2
fi

TGZ="$1"
if [[ ! -f "$TGZ" ]]; then
  echo "file not found: $TGZ" >&2
  exit 2
fi

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

REMOTE_TGZ="/tmp/$(basename "$TGZ")"
TARGET_DIR="/var/lib/veil/playbooks/docs/skills-index"

log() { printf '[veil-bootstrap-skills] %s\n' "$*"; }

log "copy tgz to target: ${REMOTE_TGZ}"
scp -P "${SSH_PORT}" "${TGZ}" "${SSH_HOST}:${REMOTE_TGZ}"

log "extract into hostPath: ${TARGET_DIR}"
if [[ -n "${SUDO_PW}" ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' mkdir -p '${TARGET_DIR}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' tar -xzf '${REMOTE_TGZ}' -C /var/lib/veil/playbooks"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' test -f '${TARGET_DIR}/cyber-skills.json'"
else
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo mkdir -p '${TARGET_DIR}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo tar -xzf '${REMOTE_TGZ}' -C /var/lib/veil/playbooks"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo test -f '${TARGET_DIR}/cyber-skills.json'"
fi

log "ok: ${TARGET_DIR}/cyber-skills.json present"

