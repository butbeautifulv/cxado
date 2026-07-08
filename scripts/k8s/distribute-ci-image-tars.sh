#!/usr/bin/env bash
# Export CI image tars on P30 and copy to k3s agent nodes (Astra podman OVAL fallback).
#
# Usage:
#   ./scripts/k8s/distribute-ci-image-tars.sh
#   ./scripts/k8s/distribute-ci-image-tars.sh --only checkov:3.2.449,python:3.11.11-slim-bookworm
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=deploy/registry.defaults.env
[[ -f "${ROOT}/deploy/registry.defaults.env" ]] && source "${ROOT}/deploy/registry.defaults.env"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

SSH_P30="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
REG="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
REPO="${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}"
TAR_DIR="/var/lib/cxado/ci-image-tars"
ONLY=""
STAGING="/tmp/cxado-ci-tars-$$"

log() { printf '[distribute-ci-tars] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

TAGS=(
  kaniko-executor:v1.23.2
  semgrep:1.117.0
  syft:v1.20.0
  trivy:0.63.0
  gitleaks:v8.22.1
  hadolint:v2.12.0-alpine
  checkov:3.2.449
  conftest:v0.56.0
  helm:3.17.2
  python:3.11.11-slim-bookworm
  alpine:3.20.3
  kubectl:1.32.2
  cosign:v2.4.0
  gitlab-runner-helper:x86_64-v19.1.1
)
if [[ -n "${ONLY}" ]]; then
  IFS=',' read -ra TAGS <<< "${ONLY}"
fi

tar_name() { echo "$1" | tr '/:' '_'; }

export_on_p30() {
  local tag="$1"
  local ref="${REG}/${REPO}/${tag}"
  local tar="${TAR_DIR}/$(tar_name "${tag}").tar"
  ssh "${SSH_P30}" env "CXADO_OFFLINE_SUDO_PW=${CXADO_OFFLINE_SUDO_PW:-}" bash -s <<EOS
set -euo pipefail
SUDO_PW="\${CXADO_OFFLINE_SUDO_PW:-}"
sudo_run() { printf '%s\n' "\${SUDO_PW}" | sudo -S -p '' "\$@"; }
sudo_run mkdir -p "${TAR_DIR}"
if [[ -s "${tar}" ]]; then
  echo "present: ${tar}"
  exit 0
fi
sudo_run k3s ctr images export "${tar}" "${ref}"
echo "exported: ${tar}"
EOS
}

push_to_agent() {
  local jump_host user host pass tag="$4"
  jump_host="$1" user="$2" host="$3"
  pass="$5"
  local tar="$(tar_name "${tag}").tar"
  mkdir -p "${STAGING}"
  scp -o ProxyJump="${jump_host}" "${jump_host}:${TAR_DIR}/${tar}" "${STAGING}/${tar}"
  scp -o ProxyJump="${jump_host}" "${STAGING}/${tar}" "${user}@${host}:/tmp/${tar}"
  ssh -o ProxyJump="${jump_host}" "${user}@${host}" \
    "echo '${pass}' | sudo -S bash -s" <<EOS
set -euo pipefail
K3S=\$(command -v k3s || echo /usr/local/bin/k3s)
mkdir -p '${TAR_DIR}'
mv /tmp/${tar} '${TAR_DIR}/${tar}'
\${K3S} ctr images import '${TAR_DIR}/${tar}'
EOS
  log "imported ${tag} on ${host}"
}

main() {
  for tag in "${TAGS[@]}"; do
    log "export ${tag} on P30"
    export_on_p30 "${tag}"
  done
  for tag in "${TAGS[@]}"; do
  push_to_agent "${SSH_P30}" astradmin 10.20.16.195 "${tag}" "${VM_01_PWD:-}"
  push_to_agent "${SSH_P30}" admin 10.20.16.185 "${tag}" "${VM_02_PWD:-}"
  done
  rm -rf "${STAGING}"
  log "done"
}

main "$@"
