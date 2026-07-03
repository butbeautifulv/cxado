#!/usr/bin/env bash
# Rsync architecture-site to k3s node (no sudo).
#
#   ./scripts/k8s/k3s-offline-bundle-arch-docs.sh
#   ./scripts/k8s/k3s-offline-bundle-arch-docs.sh --remote
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SRC="${ROOT}/docs/architecture-site"
DEST="${CXADO_ARCH_DOCS_DEST:-/home/bbv/cxado/arch-docs}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
REMOTE=0

for arg in "$@"; do
  case "$arg" in
    --dest=*) DEST="${arg#*=}" ;;
    --remote) REMOTE=1 ;;
  esac
done

[[ -f "${SRC}/index.html" ]] || { echo "missing ${SRC}/index.html" >&2; exit 1; }

rsync_site() {
  local target="$1"
  echo "[arch-docs] rsync ${SRC}/ -> ${target}/"
  mkdir -p "${target}"
  rsync -av --delete --info=progress2 \
    --exclude '.git' \
    "${SRC}/" "${target}/"
  chmod -R a+rX "${target}"
  echo "[arch-docs] done ($(du -sh "${target}" | cut -f1))"
}

if [[ "${REMOTE}" -eq 1 ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "mkdir -p '${DEST}'"
  rsync -av --delete --info=progress2 \
    --exclude '.git' \
    -e "ssh -p ${SSH_PORT}" \
    "${SRC}/" "${SSH_HOST}:${DEST}/"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "chmod -R a+rX '${DEST}' && test -f '${DEST}/index.html'"
else
  rsync_site "${DEST}"
fi
