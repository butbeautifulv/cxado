#!/usr/bin/env bash
# Deploy GitLab Runner with kubernetes executor in cxado-ci namespace on P30 k3s.
#
# Prerequisites:
#   - deploy/.secrets/cxado-k3s.env with NEXUS_*, GITLAB_RUNNER_TOKEN (glrt-...)
#   - kubectl access to P30 k3s (KUBECONFIG or SSH hop)
#
# Usage:
#   ./scripts/gitlab/setup-runner-k8s.sh bootstrap    # namespace, RBAC, nexus secrets, deploy
#   ./scripts/gitlab/setup-runner-k8s.sh register     # ensure GITLAB_RUNNER_TOKEN secret
#   ./scripts/gitlab/setup-runner-k8s.sh status
#   ./scripts/gitlab/setup-runner-k8s.sh --ssh bbv-p30-wifi bootstrap
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

MANIFEST_DIR="${ROOT}/deploy/k8s/gitlab-runner"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
PROJECT_ID="${GITLAB_PROJECT_ID:-1938}"
RUNNER_TAGS="${GITLAB_RUNNER_K8S_TAGS:-k3s,corp,p30}"
RUNNER_DESC="${GITLAB_RUNNER_K8S_DESCRIPTION:-cxado-k8s-runner}"
NS_CI="cxado-ci"
NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"

log() { printf '[gitlab-runner-k8s] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_HOST="${2:-bbv-p30-wifi}"; shift 2 ;;
    bootstrap|register|status|create-token) break ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

kctl() {
  local kubeconfig="${KUBECONFIG:-/home/bbv/.kube/config}"
  if [[ -n "${SSH_HOST}" ]]; then
    ssh "${SSH_HOST}" "export KUBECONFIG='${kubeconfig}'; k3s kubectl $*"
  else
    export KUBECONFIG="${kubeconfig}"
    if command -v kubectl >/dev/null 2>&1; then
      kubectl "$@"
    else
      k3s kubectl "$@"
    fi
  fi
}

apply_manifests() {
  local tmpdir kubeconfig="${KUBECONFIG:-/home/bbv/.kube/config}"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' RETURN
  cp "${MANIFEST_DIR}/00-namespace.yaml" "${MANIFEST_DIR}/10-rbac.yaml" "${tmpdir}/"
  sed -e "s|__NEXUS_DOCKER_REGISTRY__|${NEXUS_DOCKER_REGISTRY}|g" \
      -e "s|__CXADO_CI_REGISTRY__|${CXADO_CI_REGISTRY}|g" \
    "${MANIFEST_DIR}/20-configmap.yaml" > "${tmpdir}/20-configmap.yaml"
  sed -e "s|__NEXUS_DOCKER_REGISTRY__|${NEXUS_DOCKER_REGISTRY}|g" \
    "${MANIFEST_DIR}/30-deployment.yaml" > "${tmpdir}/30-deployment.yaml"
  if [[ -n "${SSH_HOST}" ]]; then
    local remote="/tmp/cxado-runner-$$"
    ssh "${SSH_HOST}" "rm -rf '${remote}' && mkdir -p '${remote}'"
    scp -q "${tmpdir}"/* "${SSH_HOST}:${remote}/"
    ssh "${SSH_HOST}" "export KUBECONFIG='${kubeconfig}'; k3s kubectl apply -f '${remote}/'"
    ssh "${SSH_HOST}" "rm -rf '${remote}'"
  else
    kctl apply -f "${tmpdir}/"
  fi
  rm -rf "${tmpdir}"
  trap - RETURN
}

fetch_nexus_ca() {
  local tmp host
  host="${NEXUS_DOCKER_REGISTRY%%:*}"
  tmp="$(mktemp)"
  if [[ -n "${SSH_HOST}" ]]; then
    ssh "${SSH_HOST}" "openssl s_client -connect '${host}:8345' -servername '${host}' -showcerts </dev/null 2>/dev/null \
      | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{print}'" > "${tmp}" || true
  else
    openssl s_client -connect "${host}:8345" -servername "${host}" -showcerts </dev/null 2>/dev/null \
      | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{print}' > "${tmp}" || true
  fi
  if [[ ! -s "${tmp}" ]]; then
    rm -f "${tmp}"
    echo "failed to fetch Nexus TLS chain" >&2
    exit 1
  fi
  echo "${tmp}"
}

copy_nexus_secrets_from_build_ns() {
  if kctl -n "${NS_CI}" get secret nexus-registry >/dev/null 2>&1; then
    log "nexus-registry already in ${NS_CI}"
    if ! kctl -n "${NS_CI}" get secret nexus-ca-cert >/dev/null 2>&1 \
      && kctl -n cxado-build get secret nexus-ca-cert >/dev/null 2>&1; then
      kctl -n cxado-build get secret nexus-ca-cert -o yaml \
        | sed 's/namespace: cxado-build/namespace: cxado-ci/' \
        | kctl apply -f -
    fi
    return 0
  fi
  if kctl -n cxado-build get secret nexus-registry >/dev/null 2>&1; then
    log "copy nexus secrets from cxado-build"
    kctl -n cxado-build get secret nexus-registry -o yaml \
      | sed 's/namespace: cxado-build/namespace: cxado-ci/' \
      | kctl apply -f -
    kctl -n cxado-build get secret nexus-ca-cert -o yaml \
      | sed 's/namespace: cxado-build/namespace: cxado-ci/' \
      | kctl apply -f - 2>/dev/null || true
    return 0
  fi
  return 1
}

ensure_nexus_secrets() {
  [[ -n "${NEXUS_PASSWORD:-}" ]] || { echo "missing NEXUS_PASSWORD in secrets" >&2; exit 2; }
  if copy_nexus_secrets_from_build_ns; then
    return 0
  fi
  log "secret nexus-registry in ${NS_CI}"
  kctl -n "${NS_CI}" create secret docker-registry nexus-registry \
    --docker-server="${NEXUS_DOCKER_REGISTRY}" \
    --docker-username="${NEXUS_USER:-admin-SEC}" \
    --docker-password="${NEXUS_PASSWORD}" \
    --dry-run=client -o yaml | kctl apply -f -
  log "secret nexus-ca-cert in ${NS_CI}"
  if [[ -n "${SSH_HOST}" ]]; then
    ssh "${SSH_HOST}" "set -euo pipefail
      host='${NEXUS_DOCKER_REGISTRY%%:*}'
      tmp=\$(mktemp)
      openssl s_client -connect \"\${host}:8345\" -servername \"\${host}\" -showcerts </dev/null 2>/dev/null \
        | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{print}' > \"\${tmp}\"
      test -s \"\${tmp}\"
      export KUBECONFIG='${KUBECONFIG:-/home/bbv/.kube/config}'
      k3s kubectl -n ${NS_CI} create secret generic nexus-ca-cert \
        --from-file=ca.crt=\"\${tmp}\" --dry-run=client -o yaml | k3s kubectl apply -f -
      rm -f \"\${tmp}\""
  else
    local ca_file
    ca_file="$(fetch_nexus_ca)"
    kctl -n "${NS_CI}" create secret generic nexus-ca-cert \
      --from-file=ca.crt="${ca_file}" \
      --dry-run=client -o yaml | kctl apply -f -
    rm -f "${ca_file}"
  fi
}

ensure_runner_token_secret() {
  local token="${GITLAB_RUNNER_TOKEN:-}"
  [[ -n "${token}" ]] || {
    echo "missing GITLAB_RUNNER_TOKEN (glrt-...) in ${SECRETS}" >&2
    echo "Run: $0 create-token  OR ask GitLab admin for project runner token." >&2
    exit 2
  }
  log "secret gitlab-runner-token"
  kctl -n "${NS_CI}" create secret generic gitlab-runner-token \
    --from-literal=runner-token="${token}" \
    --dry-run=client -o yaml | kctl apply -f -
}

create_runner_token() {
  local pat="${GITLAB_PAT_RUNNER:-${GITLAB_TOKEN:-}}"
  [[ -n "${pat}" ]] || { echo "missing GITLAB_PAT_RUNNER" >&2; exit 2; }
  log "POST /api/v4/user/runners (project ${PROJECT_ID}, tags: ${RUNNER_TAGS})"
  if [[ -n "${SSH_HOST}" ]]; then
    ssh "${SSH_HOST}" "curl -sk --request POST --url '${GITLAB_URL}/api/v4/user/runners' \
      --header 'PRIVATE-TOKEN: ${pat}' \
      --form 'runner_type=project_type' \
      --form 'project_id=${PROJECT_ID}' \
      --form 'description=${RUNNER_DESC}' \
      --form 'tag_list=${RUNNER_TAGS}' \
      --form 'run_untagged=false'"
  else
    curl -sk --request POST --url "${GITLAB_URL}/api/v4/user/runners" \
      --header "PRIVATE-TOKEN: ${pat}" \
      --form "runner_type=project_type" \
      --form "project_id=${PROJECT_ID}" \
      --form "description=${RUNNER_DESC}" \
      --form "tag_list=${RUNNER_TAGS}" \
      --form "run_untagged=false"
  fi
}

bootstrap() {
  log "apply manifests from ${MANIFEST_DIR}"
  apply_manifests
  ensure_nexus_secrets
  ensure_runner_token_secret
  kctl -n "${NS_CI}" rollout status deployment/gitlab-runner --timeout=180s || true
  status_runner
}

register_runner() {
  ensure_runner_token_secret
  kctl -n "${NS_CI}" rollout restart deployment/gitlab-runner
  kctl -n "${NS_CI}" rollout status deployment/gitlab-runner --timeout=120s || true
  status_runner
}

status_runner() {
  kctl -n "${NS_CI}" get pods,sa,deploy -l app.kubernetes.io/name=gitlab-runner 2>/dev/null || true
  kctl -n "${NS_CI}" logs deployment/gitlab-runner --tail=20 2>/dev/null || true
}

cmd="${1:-bootstrap}"
case "${cmd}" in
  bootstrap) bootstrap ;;
  register) register_runner ;;
  create-token) create_runner_token ;;
  status) status_runner ;;
  *)
    echo "usage: $0 [--ssh HOST] {bootstrap|register|create-token|status}" >&2
    exit 2
    ;;
esac
