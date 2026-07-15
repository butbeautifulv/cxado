#!/usr/bin/env bash
# Build egregore backend and/or UI on P30 via in-cluster Kaniko → push to Nexus.
#
# Usage:
#   TAG="$(git -C projects/egregore rev-parse --short HEAD)" \
#     ./scripts/k8s/kaniko-build-egregore.sh --tag "${TAG}"
#   ./scripts/k8s/kaniko-build-egregore.sh --backend-only --tag abc123
#   ./scripts/k8s/kaniko-build-egregore.sh --ui-only --prebuilt --tag abc123
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

BUILD_BACKEND=1
BUILD_UI=1
PREBUILT_UI=0
BUILD_TAG=""
NEXT_PUBLIC_EGRESS_SSE="${NEXT_PUBLIC_EGRESS_SSE:-1}"
NEXT_PUBLIC_STREAM_API_BASE="${NEXT_PUBLIC_STREAM_API_BASE:-}"
NEXT_PUBLIC_LANGFUSE_HOST="${NEXT_PUBLIC_LANGFUSE_HOST:-https://localhost:30001}"

log() { printf '[kaniko-build-egregore] %s\n' "$*"; }
die() { printf '[kaniko-build-egregore] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
usage: $(basename "$0") [options]

options:
  --tag TAG           image tag (default: projects/egregore short git SHA)
  --backend-only      build/push egregore backend only
  --ui-only           build/push egregore-ui only
  --prebuilt          UI: use Dockerfile.prebuilt (host must have ui/.next built)
  --help
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) BUILD_TAG="${2:-}"; shift 2 ;;
    --backend-only) BUILD_BACKEND=1; BUILD_UI=0; shift ;;
    --ui-only) BUILD_BACKEND=0; BUILD_UI=1; shift ;;
    --prebuilt) PREBUILT_UI=1; shift ;;
    --help|-h) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

if [[ -z "${NEXUS_PASSWORD:-}" ]]; then
  die "missing NEXUS_PASSWORD (set in ${SECRETS_ENV_FILE})"
fi

NEXUS_USER="${NEXUS_USER:-admin-SEC}"
export NEXUS_DOCKER_REGISTRY NEXUS_PYPI_HOST NEXUS_PYPI_REPO NEXUS_USER NEXUS_PASSWORD
export NEXUS_NPM_HOST="${NEXUS_NPM_HOST:-nexus.svo.aero:8443}" NEXUS_NPM_REPO="${NEXUS_NPM_REPO:-npm-proxy}"
export CXADO_IMAGE_REPO CXADO_UI_IMAGE_REPO KANIKO_BUILD_DIR KANIKO_EXECUTOR_IMAGE

if [[ -z "${BUILD_TAG}" ]]; then
  BUILD_TAG="$(git -C "${ROOT}/projects/egregore" rev-parse --short HEAD 2>/dev/null || echo "local")"
fi
BUILD_TAG_SLUG="$(printf '%s' "${BUILD_TAG}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"
export BUILD_TAG BUILD_TAG_SLUG

EGREGORE_GIT_STATUS="$(git -C "${ROOT}/projects/egregore" status --porcelain)"
if [[ -n "${EGREGORE_GIT_STATUS}" && "${CXADO_ALLOW_DIRTY_BUILD:-}" != "1" ]]; then
  die "projects/egregore has uncommitted changes — commit first or set CXADO_ALLOW_DIRTY_BUILD=1:
${EGREGORE_GIT_STATUS}"
fi

kubectl_remote() {
  # shellcheck disable=SC2029
  ssh -p "${SSH_PORT}" -o ConnectTimeout=20 "${SSH_HOST}" \
    "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
}

rsync_sources() {
  local remote_dest="${SSH_HOST}:${KANIKO_BUILD_DIR}/egregore/"
  log "rsync projects/egregore → ${remote_dest}"
  rsync -az --delete --no-group --no-owner \
    --exclude 'ui/node_modules' \
    --exclude 'ui/.next' \
    --exclude '__pycache__' \
    --exclude '.venv' \
    --exclude '.pytest_cache' \
    --exclude '.mypy_cache' \
    --exclude '.ruff_cache' \
    -e "ssh -p ${SSH_PORT}" \
    "${ROOT}/projects/egregore/" \
    "${remote_dest}"

  if [[ "${PREBUILT_UI}" -eq 1 ]]; then
    if [[ ! -d "${ROOT}/projects/egregore/web_ui/.next/standalone" ]]; then
      die "missing projects/egregore/web_ui/.next — run: cd projects/egregore/web_ui && bun run build"
    fi
    log "rsync web_ui/.next (prebuilt)"
    rsync -az \
      -e "ssh -p ${SSH_PORT}" \
      "${ROOT}/projects/egregore/web_ui/.next" \
      "${ROOT}/projects/egregore/web_ui/public" \
      "${SSH_HOST}:${KANIKO_BUILD_DIR}/egregore/web_ui/"
  fi

  if [[ -n "${SUDO_PW}" ]]; then
    # shellcheck disable=SC2029
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' bash -c 'chown -R root:root \"${KANIKO_BUILD_DIR}/egregore\" && chmod -R a+rX \"${KANIKO_BUILD_DIR}/egregore\"'"
  else
  # shellcheck disable=SC2029
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "sudo chown -R root:root '${KANIKO_BUILD_DIR}/egregore' && sudo chmod -R a+rX '${KANIKO_BUILD_DIR}/egregore'"
  fi
}

submit_job() {
  local template="$1"
  local job_name="$2"
  local tmp
  tmp="$(mktemp)"
  export UI_DOCKERFILE="Dockerfile.corp"
  if [[ "${PREBUILT_UI}" -eq 1 ]]; then
    export UI_DOCKERFILE="Dockerfile.prebuilt.corp"
  fi
  export NEXT_PUBLIC_EGRESS_SSE NEXT_PUBLIC_STREAM_API_BASE NEXT_PUBLIC_LANGFUSE_HOST
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
  log "tag=${BUILD_TAG} backend=${BUILD_BACKEND} ui=${BUILD_UI} prebuilt=${PREBUILT_UI}"
  rsync_sources

  if [[ "${BUILD_BACKEND}" -eq 1 ]]; then
    submit_job "${ROOT}/deploy/k8s/kaniko/20-job-egregore.yaml" "kaniko-egregore-${BUILD_TAG_SLUG}"
    wait_job "kaniko-egregore-${BUILD_TAG_SLUG}"
    log "pushed ${CXADO_IMAGE_REPO}:${BUILD_TAG}"
  fi

  if [[ "${BUILD_UI}" -eq 1 ]]; then
    submit_job "${ROOT}/deploy/k8s/kaniko/21-job-egregore-ui.yaml" "kaniko-egregore-ui-${BUILD_TAG_SLUG}"
    wait_job "kaniko-egregore-ui-${BUILD_TAG_SLUG}"
    log "pushed ${CXADO_UI_IMAGE_REPO}:${BUILD_TAG}"
  fi

  log "done"
}

main "$@"
