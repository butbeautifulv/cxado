#!/usr/bin/env bash
# Build veil-api and/or veil-mcp on P30 via in-cluster Kaniko → push to Nexus.
#
# Usage:
#   TAG="$(git -C projects/veil rev-parse --short HEAD)" \
#     ./scripts/k8s/kaniko-build-veil.sh --tag "${TAG}"
#   ./scripts/k8s/kaniko-build-veil.sh --api-only --tag abc123
#   ./scripts/k8s/kaniko-build-veil.sh --mcp-only --tag abc123
#
# Env: deploy/.secrets/cxado-k3s.env (NEXUS_PASSWORD, …), cxado-offline-env.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SECRETS_ENV_FILE="${CXADO_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/cxado-k3s.env}"
[[ -f "${SECRETS_ENV_FILE}" ]] && set -a && source "${SECRETS_ENV_FILE}" && set +a

KANIKO_BUILD_DIR="${KANIKO_BUILD_DIR:-/var/lib/cxado/kaniko-build}"
KANIKO_EXECUTOR_IMAGE="${KANIKO_EXECUTOR_IMAGE:-${CXADO_CI_REGISTRY}/kaniko-executor:v1.23.2}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

BUILD_API=1
BUILD_MCP=1
BUILD_TAG=""

log() { printf '[kaniko-build-veil] %s\n' "$*"; }
die() { printf '[kaniko-build-veil] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
usage: $(basename "$0") [options]

options:
  --tag TAG       image tag (default: projects/veil short git SHA)
  --api-only      build/push veil-api only
  --mcp-only      build/push veil-mcp only
  --help
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) BUILD_TAG="${2:-}"; shift 2 ;;
    --api-only) BUILD_API=1; BUILD_MCP=0; shift ;;
    --mcp-only) BUILD_API=0; BUILD_MCP=1; shift ;;
    --help|-h) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

if [[ -z "${NEXUS_PASSWORD:-}" ]]; then
  die "missing NEXUS_PASSWORD (set in ${SECRETS_ENV_FILE})"
fi

NEXUS_USER="${NEXUS_USER:-admin-SEC}"
export NEXUS_DOCKER_REGISTRY NEXUS_DOCKER_GROUP_REGISTRY NEXUS_USER NEXUS_PASSWORD
export NEXUS_GO_HOST="${NEXUS_GO_HOST:-nexus.svo.aero:8443}" NEXUS_GO_REPO="${NEXUS_GO_REPO:-go-proxy}"
export VEIL_API_IMAGE_REPO VEIL_MCP_IMAGE_REPO KANIKO_BUILD_DIR KANIKO_EXECUTOR_IMAGE

if [[ -z "${BUILD_TAG}" ]]; then
  BUILD_TAG="$(git -C "${ROOT}/projects/veil" rev-parse --short HEAD 2>/dev/null || echo "local")"
fi
BUILD_TAG_SLUG="$(printf '%s' "${BUILD_TAG}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"
export BUILD_TAG BUILD_TAG_SLUG

VEIL_GIT_STATUS="$(git -C "${ROOT}/projects/veil" status --porcelain 2>/dev/null || true)"
if [[ -n "${VEIL_GIT_STATUS}" && "${CXADO_ALLOW_DIRTY_BUILD:-}" != "1" ]]; then
  die "projects/veil has uncommitted changes — commit first or set CXADO_ALLOW_DIRTY_BUILD=1:
${VEIL_GIT_STATUS}"
fi

kubectl_remote() {
  # shellcheck disable=SC2029
  ssh -p "${SSH_PORT}" -o ConnectTimeout=20 "${SSH_HOST}" \
    "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
}

rsync_sources() {
  local remote_dest="${SSH_HOST}:${KANIKO_BUILD_DIR}/veil/"
  log "rsync projects/veil → ${remote_dest}"
  rsync -az --delete --no-group --no-owner \
    --exclude '.git' \
    --exclude '**/node_modules' \
    --exclude '**/.cache' \
    --exclude '**/bin' \
    --exclude '**/dist' \
    -e "ssh -p ${SSH_PORT}" \
    "${ROOT}/projects/veil/" \
    "${remote_dest}"

  if [[ -n "${SUDO_PW}" ]]; then
    # shellcheck disable=SC2029
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' bash -c 'chown -R root:root \"${KANIKO_BUILD_DIR}/veil\" && chmod -R a+rX \"${KANIKO_BUILD_DIR}/veil\"'"
  else
    # shellcheck disable=SC2029
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "sudo chown -R root:root '${KANIKO_BUILD_DIR}/veil' && sudo chmod -R a+rX '${KANIKO_BUILD_DIR}/veil'"
  fi
}

submit_job() {
  local template="$1"
  local job_name="$2"
  local tmp
  tmp="$(mktemp)"
  envsubst < "${template}" > "${tmp}"
  log "apply Job ${job_name}"
  kubectl_remote delete job "${job_name}" -n cxado-build --ignore-not-found=true
  kubectl_remote apply -f - < "${tmp}"
  rm -f "${tmp}"
}

wait_job() {
  local job_name="$1"
  log "wait Job ${job_name}"
  if ! kubectl_remote wait --for=condition=complete "job/${job_name}" -n cxado-build --timeout=45m; then
    log "Job failed — logs:"
    kubectl_remote logs "job/${job_name}" -n cxado-build --all-containers=true || true
    kubectl_remote describe "job/${job_name}" -n cxado-build || true
    die "Kaniko job ${job_name} failed"
  fi
  log "OK  ${job_name}"
}

main() {
  log "tag=${BUILD_TAG} api=${BUILD_API} mcp=${BUILD_MCP}"
  rsync_sources

  if [[ "${BUILD_API}" -eq 1 ]]; then
    submit_job "${ROOT}/deploy/k8s/kaniko/22-job-veil-api.yaml" "kaniko-veil-api-${BUILD_TAG_SLUG}"
    wait_job "kaniko-veil-api-${BUILD_TAG_SLUG}"
    log "pushed ${VEIL_API_IMAGE_REPO}:${BUILD_TAG}"
  fi

  if [[ "${BUILD_MCP}" -eq 1 ]]; then
    submit_job "${ROOT}/deploy/k8s/kaniko/23-job-veil-mcp.yaml" "kaniko-veil-mcp-${BUILD_TAG_SLUG}"
    wait_job "kaniko-veil-mcp-${BUILD_TAG_SLUG}"
    log "pushed ${VEIL_MCP_IMAGE_REPO}:${BUILD_TAG}"
  fi

  log "done"
}

main "$@"
