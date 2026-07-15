#!/usr/bin/env bash
# Nexus build loop entrypoint — Kaniko on P30 → helm upgrade (no tar/rsync import).
#
# Usage:
#   TAG="$(git -C projects/egregore rev-parse --short HEAD)" \
#     ./scripts/k8s/cxado-nexus-deploy.sh --build --tag "${TAG}"
#   ./scripts/k8s/cxado-nexus-deploy.sh --skip-build --tag "${TAG}"
#   ./scripts/k8s/cxado-nexus-deploy.sh --build --prebuilt-ui --tag "${TAG}"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

DO_BUILD=0
SKIP_BUILD=0
PREBUILT_UI=0
TAG=""
BUILD_ARGS=()

log() { printf '[cxado-nexus-deploy] %s\n' "$*"; }
die() { printf '[cxado-nexus-deploy] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
usage: $(basename "$0") [options]

options:
  --build           Kaniko build + push to Nexus, then helm upgrade
  --skip-build      helm upgrade only (image already in Nexus)
  --tag TAG         image tag (default: egregore git short SHA)
  --prebuilt-ui     UI: use Dockerfile.prebuilt.corp (host web_ui/.next required)
  --backend-only    build backend only
  --ui-only         build UI only
  --help
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) DO_BUILD=1; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --tag) TAG="${2:-}"; shift 2 ;;
    --prebuilt-ui) PREBUILT_UI=1; shift ;;
    --backend-only) BUILD_ARGS+=(--backend-only); shift ;;
    --ui-only) BUILD_ARGS+=(--ui-only); shift ;;
    --help|-h) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

if [[ "${DO_BUILD}" -eq 0 && "${SKIP_BUILD}" -eq 0 ]]; then
  DO_BUILD=1
fi
if [[ "${DO_BUILD}" -eq 1 && "${SKIP_BUILD}" -eq 1 ]]; then
  die "use either --build or --skip-build, not both"
fi

if [[ -z "${TAG}" ]]; then
  TAG="$(git -C "${ROOT}/projects/egregore" rev-parse --short HEAD 2>/dev/null || echo "local")"
fi

if [[ "${DO_BUILD}" -eq 1 ]]; then
  log "build tag=${TAG}"
  KANIKO_CMD=("${ROOT}/scripts/k8s/kaniko-build-egregore.sh" --tag "${TAG}" "${BUILD_ARGS[@]}")
  if [[ "${PREBUILT_UI}" -eq 1 ]]; then
    KANIKO_CMD+=(--prebuilt)
  fi
  "${KANIKO_CMD[@]}"
fi

log "helm upgrade tag=${TAG}"
CXADO_OFFLINE_TAG="${TAG}" "${ROOT}/scripts/k8s/egregore-helm-upgrade.sh"

log "done"
