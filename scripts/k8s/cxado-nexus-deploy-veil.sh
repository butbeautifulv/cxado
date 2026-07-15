#!/usr/bin/env bash
# Nexus build loop entrypoint — Kaniko on P30 → veil helm upgrade (no tar/rsync import).
#
# Usage:
#   TAG="$(git -C projects/veil rev-parse --short HEAD)" \
#     ./scripts/k8s/cxado-nexus-deploy-veil.sh --build --tag "${TAG}"
#   ./scripts/k8s/cxado-nexus-deploy-veil.sh --skip-build --tag "${TAG}"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

DO_BUILD=0
SKIP_BUILD=0
TAG=""
BUILD_ARGS=()

log() { printf '[cxado-nexus-deploy-veil] %s\n' "$*"; }
die() { printf '[cxado-nexus-deploy-veil] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
usage: $(basename "$0") [options]

options:
  --build           Kaniko build + push to Nexus, then helm upgrade
  --skip-build      helm upgrade only (images already in Nexus)
  --tag TAG         image tag (default: veil git short SHA)
  --api-only        build veil-api only
  --mcp-only        build veil-mcp only
  --help
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) DO_BUILD=1; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --tag) TAG="${2:-}"; shift 2 ;;
    --api-only) BUILD_ARGS+=(--api-only); shift ;;
    --mcp-only) BUILD_ARGS+=(--mcp-only); shift ;;
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
  TAG="$(git -C "${ROOT}/projects/veil" rev-parse --short HEAD 2>/dev/null || echo "local")"
fi

if [[ "${DO_BUILD}" -eq 1 ]]; then
  log "build tag=${TAG}"
  "${ROOT}/scripts/k8s/kaniko-build-veil.sh" --tag "${TAG}" "${BUILD_ARGS[@]}"
fi

log "helm upgrade tag=${TAG}"
VEIL_OFFLINE_TAG="${TAG}" "${ROOT}/scripts/k8s/veil-helm-upgrade.sh"

log "done"
