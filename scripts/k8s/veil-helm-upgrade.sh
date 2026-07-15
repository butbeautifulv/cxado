#!/usr/bin/env bash
# Incremental veil graph plane helm upgrade on k3s offline (Nexus pull — no tar import).
#
# Build + push images first:
#   TAG="$(git -C projects/veil rev-parse --short HEAD)" \
#     ./scripts/k8s/kaniko-build-veil.sh --tag "${TAG}"
# Or use the entrypoint:
#   ./scripts/k8s/cxado-nexus-deploy-veil.sh --build --tag "${TAG}"
#
# Usage:
#   VEIL_OFFLINE_TAG=abc123 ./scripts/k8s/veil-helm-upgrade.sh
#   VEIL_OFFLINE_TAG=abc123 ./scripts/k8s/veil-helm-upgrade.sh --with-workers-obs
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

TAG="${VEIL_OFFLINE_TAG:-${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}}"
SSH_HOST="${VEIL_OFFLINE_SSH_HOST:-${CXADO_OFFLINE_SSH_HOST}}"
SSH_PORT="${VEIL_OFFLINE_SSH_PORT:-${CXADO_OFFLINE_SSH_PORT}}"
WITH_WORKERS_OBS=0
SKIP_NEXUS_PREFLIGHT="${SKIP_NEXUS_PREFLIGHT:-0}"

for arg in "$@"; do
  case "$arg" in
    --with-workers-obs) WITH_WORKERS_OBS=1 ;;
  esac
done

KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
HELM="KUBECONFIG=/home/bbv/.kube/config helm"

log() { printf '[veil-helm-upgrade] %s\n' "$*"; }
die() { printf '[veil-helm-upgrade] ERROR: %s\n' "$*" >&2; exit 1; }

export VEIL_API_IMAGE_REPO="${VEIL_API_IMAGE_REPO:-${NEXUS_DOCKER_REGISTRY}/${NEXUS_CXADO_DOCKER_REPO}/veil-api}"
export VEIL_MCP_IMAGE_REPO="${VEIL_MCP_IMAGE_REPO:-${NEXUS_DOCKER_REGISTRY}/${NEXUS_CXADO_DOCKER_REPO}/veil-mcp}"

log "tag=${TAG} ssh=${SSH_HOST}:${SSH_PORT} workers_obs=${WITH_WORKERS_OBS}"
log "api=${VEIL_API_IMAGE_REPO}:${TAG} mcp=${VEIL_MCP_IMAGE_REPO}:${TAG}"

nexus_preflight_pull() {
  local image_ref="$1"
  if [[ "${SKIP_NEXUS_PREFLIGHT}" == "1" ]]; then
    log "skip Nexus preflight for ${image_ref}"
    return 0
  fi
  log "preflight ctr pull ${image_ref}"
  if ssh -p "${SSH_PORT}" "${SSH_HOST}" \
    "K3S_CONFIG_FILE=/dev/null k3s ctr images pull '${image_ref}'" >/dev/null 2>&1; then
    log "preflight ok: ${image_ref}"
    return 0
  fi
  die "Nexus image missing: ${image_ref} — build first: ./scripts/k8s/kaniko-build-veil.sh --tag ${TAG}"
}

nexus_preflight_pull "${VEIL_API_IMAGE_REPO}:${TAG}"
nexus_preflight_pull "${VEIL_MCP_IMAGE_REPO}:${TAG}"

REMOTE_VALUES="/tmp/values-veil-offline.${TAG}.$$.yaml"
LOCAL_VALUES="$(mktemp)"
trap 'rm -f "${LOCAL_VALUES}"; ssh -p "${SSH_PORT}" "${SSH_HOST}" "rm -f ${REMOTE_VALUES}" >/dev/null 2>&1 || true' EXIT

TAG="${TAG}" VEIL_OFFLINE_TAG="${TAG}" \
  "${ROOT}/scripts/gitlab/render-veil-values.sh" > "${LOCAL_VALUES}"
if grep -q '__VEIL_' "${LOCAL_VALUES}"; then
  die "unresolved placeholder in rendered values"
fi

ssh -p "${SSH_PORT}" "${SSH_HOST}" "cat >${REMOTE_VALUES}" < "${LOCAL_VALUES}"

rsync -a -e "ssh -p ${SSH_PORT}" \
  "${ROOT}/projects/veil/deploy/helm/veil/" \
  "${SSH_HOST}:/tmp/veil-helm/"

HELM_ARGS=(-n veil -f "${REMOTE_VALUES}" --set "global.imageTag=${TAG}")

if [[ "${WITH_WORKERS_OBS}" -eq 1 ]]; then
  scp -P "${SSH_PORT}" \
    "${ROOT}/deploy/k8s/veil-offline/values-workers-obs.yaml" \
    "${SSH_HOST}:/tmp/values-workers-obs.yaml"
  HELM_ARGS+=(-f /tmp/values-workers-obs.yaml)
fi

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${HELM} upgrade --install veil /tmp/veil-helm ${HELM_ARGS[*]} --force-conflicts"

log "helm upgrade applied (no global --wait)"

log "rollout graph plane"
ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n veil rollout status deploy/veil-veil-api --timeout=300s"
ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n veil rollout status deploy/veil-veil-mcp --timeout=300s"

if [[ "${WITH_WORKERS_OBS}" -eq 1 ]]; then
  log "rollout workers (workers-obs)"
  for deploy in veil-veil-ingest-worker veil-veil-pipeline-worker veil-veil-engage-events-worker; do
    if ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "${KCTL} -n veil get deploy/${deploy}" >/dev/null 2>&1; then
      ssh -p "${SSH_PORT}" "${SSH_HOST}" \
        "${KCTL} -n veil rollout status deploy/${deploy} --timeout=300s"
    else
      log "skip rollout ${deploy} (not deployed)"
    fi
  done
fi

log "done"
