#!/usr/bin/env bash
# Build cxado app images and load into kind (local dev).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLUSTER_NAME="${CXADO_KIND_CLUSTER:-cxado}"
TAG="${CXADO_IMAGE_TAG:-local}"

build_and_load() {
  local name="$1"
  local context="$2"
  local dockerfile="${3:-Dockerfile}"
  echo "Building ${name}:${TAG} ..."
  docker build -t "${name}:${TAG}" -f "${context}/${dockerfile}" "${context}"
  kind load docker-image "${name}:${TAG}" --name "$CLUSTER_NAME"
}

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "kind cluster '$CLUSTER_NAME' not found — run make cxado-kind-up first" >&2
  exit 1
fi

build_and_load cxado/egregore "${ROOT}/projects/egregore"
build_and_load cxado/egregore-ui "${ROOT}/projects/egregore/web_ui"

if [[ -f "${ROOT}/projects/veil/deploy/knowledge/docker/api.Dockerfile" ]]; then
  docker build -t "veil-api:${TAG}" \
    -f "${ROOT}/projects/veil/deploy/knowledge/docker/api.Dockerfile" \
    "${ROOT}/projects/veil"
  kind load docker-image "veil-api:${TAG}" --name "$CLUSTER_NAME"
  docker build -t "veil-mcp:${TAG}" \
    -f "${ROOT}/projects/veil/deploy/knowledge/docker/mcp.Dockerfile" \
    "${ROOT}/projects/veil"
  kind load docker-image "veil-mcp:${TAG}" --name "$CLUSTER_NAME"
fi

echo "Images loaded into kind cluster '$CLUSTER_NAME'"
