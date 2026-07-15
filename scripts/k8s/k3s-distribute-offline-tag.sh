#!/usr/bin/env bash
# DEPRECATED — workers pull from Nexus via registries.yaml; use cxado-nexus-deploy.sh.
# Distribute backend + UI image tars for an offline tag to all worker nodes.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-20260713-apiha ./scripts/k8s/k3s-distribute-offline-tag.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

TAG="${CXADO_OFFLINE_TAG:-}"
if [[ -z "${TAG}" ]]; then
  echo "usage: CXADO_OFFLINE_TAG=offline-YYYYMMDD $0" >&2
  exit 2
fi

BACKEND_TAR="${CXADO_OFFLINE_TAR:-/tmp/cxado_offline_egregore_${TAG}.tar}"
UI_TAR="${CXADO_OFFLINE_UI_TAR:-/tmp/cxado_offline_egregore_ui_${TAG}.tar}"

log() { printf '[k3s-distribute-offline-tag] %s\n' "$*"; }
die() { printf '[k3s-distribute-offline-tag] ERROR: %s\n' "$*" >&2; exit 1; }

for tar in "${BACKEND_TAR}" "${UI_TAR}"; do
  if [[ ! -f "${tar}" ]]; then
    die "missing ${tar} — build with k3s-offline-bundle-egregore*.sh first"
  fi
done

log "tag=${TAG} workers-only distribute"
"${ROOT}/scripts/k8s/k3s-distribute-image.sh" --workers-only "${BACKEND_TAR}"
"${ROOT}/scripts/k8s/k3s-distribute-image.sh" --workers-only "${UI_TAR}"

log "done — restart ImagePullBackOff pods if needed:"
log "  ./scripts/k8s/k3s-connect.sh kubectl delete pod -n cxado-app -l 'app in (egregore-api,egregore-ui)' --field-selector=status.phase!=Running"
