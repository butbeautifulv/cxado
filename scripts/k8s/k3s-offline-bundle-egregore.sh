#!/usr/bin/env bash
# Build egregore backend image and import into k3s containerd on the target.
# Bundle Next.js UI separately: k3s-offline-bundle-egregore-ui.sh
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-offline-bundle-egregore.sh
#
# Env:
# - CXADO_OFFLINE_SSH_HOST (default: bbv@10.8.184.22)
# - CXADO_OFFLINE_SSH_PORT (default: 22012)
# - CXADO_OFFLINE_SUDO_PW  (optional; if omitted expects passwordless sudo)
# - NEXT_PUBLIC_LANGFUSE_HOST — unused (Next.js UI not bundled)
# - CXADO_ALLOW_DIRTY_BUILD=1 — skip the uncommitted-changes guard below
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

OUT_TAR="${CXADO_OFFLINE_TAR:-/tmp/cxado_offline_egregore_${TAG}.tar}"

log() { printf '[k3s-offline-egregore] %s\n' "$*"; }
die() { printf '[k3s-offline-egregore] ERROR: %s\n' "$*" >&2; exit 1; }

# Guard against building an untraceable image: on 2026-07-13 an offline image
# (offline-20260713-busfix) was built and deployed from an uncommitted working
# tree, so the running image couldn't be mapped back to any commit. Fail loudly
# unless explicitly overridden.
EGREGORE_GIT_STATUS="$(git -C "${ROOT}/projects/egregore" status --porcelain)"
if [[ -n "${EGREGORE_GIT_STATUS}" && "${CXADO_ALLOW_DIRTY_BUILD:-}" != "1" ]]; then
  die "projects/egregore has uncommitted changes — commit first, or set CXADO_ALLOW_DIRTY_BUILD=1 to build anyway (image tag will not map to a commit):
${EGREGORE_GIT_STATUS}"
fi
EGREGORE_GIT_SHA="$(git -C "${ROOT}/projects/egregore" rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "projects/egregore @ ${EGREGORE_GIT_SHA}$([[ -n "${EGREGORE_GIT_STATUS}" ]] && echo "-dirty" || true)"

export DOCKER_BUILDKIT=1
CACHE_TAG="${CXADO_OFFLINE_CACHE_TAG:-cache}"

if [[ "${CXADO_SKIP_BUILD:-}" == "1" ]]; then
  if ! docker image inspect "cxado/egregore:${TAG}" >/dev/null 2>&1; then
    die "CXADO_SKIP_BUILD=1 but cxado/egregore:${TAG} not found locally"
  fi
  log "skip build (CXADO_SKIP_BUILD=1) — using cxado/egregore:${TAG}"
else
  log "build cxado/egregore:${TAG}"
  docker build \
    --cache-from "cxado/egregore:${CACHE_TAG}" \
    -t "cxado/egregore:${TAG}" \
    -t "cxado/egregore:${CACHE_TAG}" \
    -f "${ROOT}/projects/egregore/Dockerfile" \
    "${ROOT}/projects/egregore"
fi

if [[ ! -f "${OUT_TAR}" ]]; then
  log "save -> ${OUT_TAR}"
  docker save -o "${OUT_TAR}" "cxado/egregore:${TAG}"
fi
ls -lh "${OUT_TAR}"

log "transfer bundle to target (rsync)"
rsync -avP --info=progress2 -e "ssh -p ${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"

remote_tar="/tmp/$(basename "${OUT_TAR}")"
log "import into k3s containerd: ${remote_tar}"
if [[ -n "${SUDO_PW}" ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images import '${remote_tar}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images ls | grep -E 'cxado/egregore' || true"
else
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images ls | grep -E 'cxado/egregore' || true"
fi

log "distribute to worker nodes"
"${ROOT}/scripts/k8s/k3s-distribute-image.sh" --workers-only "${OUT_TAR}"

log "done"

