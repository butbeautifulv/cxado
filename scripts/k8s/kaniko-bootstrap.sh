#!/usr/bin/env bash
# Bootstrap cxado-build namespace for in-cluster Kaniko jobs on P30 k3s.
#
# Usage:
#   ./scripts/k8s/kaniko-bootstrap.sh
#   ./scripts/k8s/kaniko-bootstrap.sh --ssh bbv-p30-wifi
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
KANIKO_BUILD_DIR="${KANIKO_BUILD_DIR:-/var/lib/cxado/kaniko-build}"
MANIFEST_DIR="${ROOT}/deploy/k8s/kaniko"

SSH_VIA=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_VIA="${2:-bbv-p30-wifi}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[kaniko-bootstrap] %s\n' "$*"; }

if [[ -z "${NEXUS_PASSWORD}" ]]; then
  echo "missing NEXUS_PASSWORD in ${SECRETS}" >&2
  exit 2
fi

fetch_nexus_ca() {
  local tmp
  tmp="$(mktemp)"
  openssl s_client -connect "${NEXUS_DOCKER_REGISTRY%%:*}:8345" \
    -servername "${NEXUS_DOCKER_REGISTRY%%:*}" -showcerts </dev/null 2>/dev/null \
    | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{print}' > "${tmp}" || true
  if [[ ! -s "${tmp}" ]]; then
    rm -f "${tmp}"
    echo "failed to fetch Nexus TLS chain" >&2
    exit 1
  fi
  echo "${tmp}"
}

dockerconfig_b64() {
  local auth
  auth="$(printf '%s:%s' "${NEXUS_USER}" "${NEXUS_PASSWORD}" | base64 -w0 2>/dev/null || printf '%s:%s' "${NEXUS_USER}" "${NEXUS_PASSWORD}" | base64)"
  printf '{"auths":{"%s":{"username":"%s","password":"%s","auth":"%s"}}}' \
    "${NEXUS_DOCKER_REGISTRY}" "${NEXUS_USER}" "${NEXUS_PASSWORD}" "${auth}" \
    | base64 -w0 2>/dev/null || \
    printf '{"auths":{"%s":{"username":"%s","password":"%s","auth":"%s"}}}' \
    "${NEXUS_DOCKER_REGISTRY}" "${NEXUS_USER}" "${NEXUS_PASSWORD}" "${auth}" | base64
}

apply_local() {
  local ca_file dc_b64
  ca_file="$(fetch_nexus_ca)"
  dc_b64="$(dockerconfig_b64)"

  log "ensure hostPath ${KANIKO_BUILD_DIR}"
  if [[ -n "${CXADO_OFFLINE_SUDO_PW:-}" ]]; then
    printf '%s\n' "${CXADO_OFFLINE_SUDO_PW}" | sudo -S -p "" mkdir -p "${KANIKO_BUILD_DIR}"
    printf '%s\n' "${CXADO_OFFLINE_SUDO_PW}" | sudo -S -p "" chmod 1777 "${KANIKO_BUILD_DIR}"
  else
    sudo mkdir -p "${KANIKO_BUILD_DIR}"
    sudo chmod 1777 "${KANIKO_BUILD_DIR}"
  fi

  export KUBECONFIG="${KUBECONFIG:-/home/bbv/.kube/config}"
  log "apply manifests"
  k3s kubectl apply -f "${MANIFEST_DIR}/00-namespace.yaml"
  k3s kubectl apply -f "${MANIFEST_DIR}/10-serviceaccount.yaml"

  log "secret nexus-registry (cxado-build + cxado-app)"
  k3s kubectl -n cxado-build create secret docker-registry nexus-registry \
    --docker-server="${NEXUS_DOCKER_REGISTRY}" \
    --docker-username="${NEXUS_USER}" \
    --docker-password="${NEXUS_PASSWORD}" \
    --dry-run=client -o yaml | k3s kubectl apply -f -
  k3s kubectl create ns cxado-app 2>/dev/null || true
  k3s kubectl -n cxado-app create secret docker-registry nexus-registry \
    --docker-server="${NEXUS_DOCKER_REGISTRY}" \
    --docker-username="${NEXUS_USER}" \
    --docker-password="${NEXUS_PASSWORD}" \
    --dry-run=client -o yaml | k3s kubectl apply -f -

  log "secret nexus-ca-cert"
  k3s kubectl -n cxado-build create secret generic nexus-ca-cert \
    --from-file=ca.crt="${ca_file}" \
    --dry-run=client -o yaml | k3s kubectl apply -f -

  rm -f "${ca_file}"
  log "bootstrap complete"
}

apply_remote() {
  log "remote bootstrap on ${SSH_VIA}"
  ssh "${SSH_VIA}" "cd '${ROOT}' && ./scripts/k8s/kaniko-bootstrap.sh"
}

if [[ -n "${SSH_VIA}" ]]; then
  apply_remote
else
  apply_local
fi
