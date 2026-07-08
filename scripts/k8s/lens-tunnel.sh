#!/usr/bin/env bash
# SSH tunnel to P30 k3s API for Lens / kubectl on the laptop.
#
# Usage:
#   ./scripts/k8s/lens-tunnel.sh start    # localhost:16443 -> P30:6443
#   ./scripts/k8s/lens-tunnel.sh stop
#   ./scripts/k8s/lens-tunnel.sh status
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh" 2>/dev/null || true

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
LOCAL_PORT="${CXADO_LENS_LOCAL_PORT:-16443}"
REMOTE_PORT=6443
PID_FILE="${HOME}/.cache/cxado-k3s-lens-tunnel.pid"

mkdir -p "$(dirname "${PID_FILE}")"

start() {
  if status_quiet; then
    echo "tunnel already up on 127.0.0.1:${LOCAL_PORT}"
    return 0
  fi
  ssh -f -N \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" \
    "${SSH_HOST}"
  sleep 0.5
  if curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1:${LOCAL_PORT}/" | grep -qE '401|403'; then
    pgrep -f "ssh -f -N.*${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" | head -1 >"${PID_FILE}" || true
    echo "tunnel up: https://127.0.0.1:${LOCAL_PORT} (via ${SSH_HOST})"
  else
    echo "tunnel failed — API not reachable on 127.0.0.1:${LOCAL_PORT}" >&2
    exit 1
  fi
}

stop() {
  if [[ -f "${PID_FILE}" ]]; then
    kill "$(cat "${PID_FILE}")" 2>/dev/null || true
    rm -f "${PID_FILE}"
  fi
  pkill -f "ssh -f -N.*${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" 2>/dev/null || true
  echo "tunnel stopped"
}

status_quiet() {
  curl -sk -o /dev/null "https://127.0.0.1:${LOCAL_PORT}/" 2>/dev/null
}

status() {
  if status_quiet; then
    echo "tunnel up: 127.0.0.1:${LOCAL_PORT} -> ${SSH_HOST}:127.0.0.1:${REMOTE_PORT}"
  else
    echo "tunnel down"
    return 1
  fi
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) echo "usage: $0 {start|stop|status}" >&2; exit 2 ;;
esac
