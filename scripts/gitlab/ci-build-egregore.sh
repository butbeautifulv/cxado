#!/usr/bin/env bash
# Build cxado/egregore image on P30 CI runner and import into local k3s containerd.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TAG="${CXADO_IMAGE_TAG:-${CI_COMMIT_SHORT_SHA:-offline-$(date +%Y%m%d)}}"
DOCKERFILE="${ROOT}/projects/egregore/Dockerfile"
CONTEXT="${ROOT}/projects/egregore"

log() { printf '[ci-build-egregore] %s\n' "$*"; }

if [[ ! -f "${DOCKERFILE}" ]]; then
  echo "missing ${DOCKERFILE} — run ci-submodule-init.sh first" >&2
  exit 2
fi

export DOCKER_BUILDKIT=1
log "build cxado/egregore:${TAG}"
docker build \
  -t "cxado/egregore:${TAG}" \
  -f "${DOCKERFILE}" \
  "${CONTEXT}"

OUT_TAR="/tmp/cxado_egregore_${TAG}.tar"
log "save -> ${OUT_TAR}"
docker save -o "${OUT_TAR}" "cxado/egregore:${TAG}"

log "import into k3s containerd"
if [[ -n "${CXADO_OFFLINE_SUDO_PW:-}" ]]; then
  printf '%s\n' "${CXADO_OFFLINE_SUDO_PW}" | /usr/bin/sudo.ws -S k3s ctr images import "${OUT_TAR}"
else
  sudo k3s ctr images import "${OUT_TAR}"
fi

k3s ctr images ls | grep -E 'cxado/egregore' || true

mkdir -p "${ROOT}/.ci"
echo "${TAG}" > "${ROOT}/.ci/image-tag"
log "tag written: ${TAG}"
