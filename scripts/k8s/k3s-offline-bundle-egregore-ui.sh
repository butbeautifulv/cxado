#!/usr/bin/env bash
# DEPRECATED — use ./scripts/k8s/cxado-nexus-deploy.sh --build --prebuilt-ui (or default UI Kaniko).
# Build egregore Next.js UI image and import into k3s containerd on the target.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-offline-bundle-egregore-ui.sh
#
# Env:
# - CXADO_OFFLINE_SSH_HOST / CXADO_OFFLINE_SSH_PORT (see cxado-offline-env.sh)
# - CXADO_OFFLINE_SUDO_PW  (optional; if omitted expects passwordless sudo)
# - NEXT_PUBLIC_EGRESS_SSE=1 (default) — browser SSE via nginx gateway (direct /v1/)
# - NEXT_PUBLIC_STREAM_API_BASE="" (default) — same-origin SSE through TLS gateway
# - CXADO_ALLOW_DIRTY_BUILD=1 — skip the uncommitted-changes guard below
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

OUT_TAR="${CXADO_OFFLINE_UI_TAR:-/tmp/cxado_offline_egregore_ui_${TAG}.tar}"
NEXT_PUBLIC_EGRESS_SSE="${NEXT_PUBLIC_EGRESS_SSE:-1}"
NEXT_PUBLIC_STREAM_API_BASE="${NEXT_PUBLIC_STREAM_API_BASE:-}"
NEXT_PUBLIC_LANGFUSE_HOST="${NEXT_PUBLIC_LANGFUSE_HOST:-https://localhost:30001}"

log() { printf '[k3s-offline-egregore-ui] %s\n' "$*"; }
die() { printf '[k3s-offline-egregore-ui] ERROR: %s\n' "$*" >&2; exit 1; }

# Guard against building an untraceable image — see k3s-offline-bundle-egregore.sh.
EGREGORE_GIT_STATUS="$(git -C "${ROOT}/projects/egregore" status --porcelain)"
if [[ -n "${EGREGORE_GIT_STATUS}" && "${CXADO_ALLOW_DIRTY_BUILD:-}" != "1" ]]; then
  die "projects/egregore has uncommitted changes — commit first, or set CXADO_ALLOW_DIRTY_BUILD=1 to build anyway (image tag will not map to a commit):
${EGREGORE_GIT_STATUS}"
fi
EGREGORE_GIT_SHA="$(git -C "${ROOT}/projects/egregore" rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "projects/egregore @ ${EGREGORE_GIT_SHA}$([[ -n "${EGREGORE_GIT_STATUS}" ]] && echo "-dirty" || true)"

export DOCKER_BUILDKIT=1
CACHE_TAG="${CXADO_OFFLINE_UI_CACHE_TAG:-cache}"

log "build cxado/egregore-ui:${TAG} (NEXT_PUBLIC_EGRESS_SSE=${NEXT_PUBLIC_EGRESS_SSE}, NEXT_PUBLIC_STREAM_API_BASE=${NEXT_PUBLIC_STREAM_API_BASE:-<empty>})"
docker build \
  --cache-from "cxado/egregore-ui:${CACHE_TAG}" \
  --build-arg "NEXT_PUBLIC_EGRESS_SSE=${NEXT_PUBLIC_EGRESS_SSE}" \
  --build-arg "NEXT_PUBLIC_STREAM_API_BASE=${NEXT_PUBLIC_STREAM_API_BASE}" \
  --build-arg "NEXT_PUBLIC_LANGFUSE_HOST=${NEXT_PUBLIC_LANGFUSE_HOST}" \
  -t "cxado/egregore-ui:${TAG}" \
  -t "cxado/egregore-ui:${CACHE_TAG}" \
  -f "${ROOT}/projects/egregore/ui/Dockerfile" \
  "${ROOT}/projects/egregore/ui"

log "save -> ${OUT_TAR}"
docker save -o "${OUT_TAR}" "cxado/egregore-ui:${TAG}"
ls -lh "${OUT_TAR}"

log "transfer bundle to target"
if command -v rsync >/dev/null 2>&1; then
  rsync -avP -e "ssh -p ${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
else
  scp -P "${SSH_PORT}" "${OUT_TAR}" "${SSH_HOST}:/tmp/"
fi

remote_tar="/tmp/$(basename "${OUT_TAR}")"
log "import into k3s containerd: ${remote_tar}"
if [[ -n "${SUDO_PW}" ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images import '${remote_tar}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' k3s ctr images ls | grep -E 'cxado/egregore-ui' || true"
else
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images import '${remote_tar}'"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "sudo k3s ctr images ls | grep -E 'cxado/egregore-ui' || true"
fi

log "distribute to worker nodes"
"${ROOT}/scripts/k8s/k3s-distribute-image.sh" --workers-only "${OUT_TAR}"

log "done"
