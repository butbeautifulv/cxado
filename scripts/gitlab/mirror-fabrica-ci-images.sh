#!/usr/bin/env bash
# Mirror CI images (fabrica OSS pins + runner/kaniko) into Nexus cxado-docker hosted repo.
#
# Usage:
#   ./scripts/gitlab/mirror-fabrica-ci-images.sh
#   ./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi
#   ./scripts/gitlab/mirror-fabrica-ci-images.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
CXADO_REPO="${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
KANIKO_VERSION="${KANIKO_EXECUTOR_VERSION:-v1.23.2}"
RUNNER_HELPER_VERSION="${GITLAB_RUNNER_HELPER_VERSION:-x86_64-v19.1.1}"
SSH_VIA=""
DRY_RUN=false

log() { printf '[mirror-fabrica-ci] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_VIA="${2:-bbv-p30-wifi}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "${NEXUS_PASSWORD}" ]] || { echo "missing NEXUS_PASSWORD in ${SECRETS}" >&2; exit 2; }

# source|dest_name (under cxado-docker/)
IMAGES=(
  "gcr.io/kaniko-project/executor:${KANIKO_VERSION}|kaniko-executor:${KANIKO_VERSION}"
  "registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:${RUNNER_HELPER_VERSION}|gitlab-runner-helper:${RUNNER_HELPER_VERSION}"
  "returntocorp/semgrep:1.117.0|semgrep:1.117.0"
  "anchore/syft:v1.20.0|syft:v1.20.0"
  "aquasec/trivy:0.63.0|trivy:0.63.0"
  "ghcr.io/gitleaks/gitleaks:v8.22.1|gitleaks:v8.22.1"
  "hadolint/hadolint:v2.12.0-alpine|hadolint:v2.12.0-alpine"
  "ghcr.io/openpolicyagent/conftest:v0.56.0|conftest:v0.56.0"
  "alpine/helm:3.17.2|helm:3.17.2"
  "python:3.11.11-slim-bookworm|python:3.11.11-slim-bookworm"
  "alpine:3.20.3|alpine:3.20.3"
  "bitnami/kubectl:1.32.2|kubectl:1.32.2"
  "docker:24.0.9-cli|docker:24.0.9-cli"
  "gcr.io/projectsigstore/cosign:v2.4.0|cosign:v2.4.0"
)

mirror_one() {
  local src="$1" dest_name="$2"
  local dest="${NEXUS_DOCKER_REGISTRY}/${CXADO_REPO}/${dest_name}"
  log "mirror ${src} -> ${dest}"
  if [[ "${DRY_RUN}" == true ]]; then
    return 0
  fi
  if [[ -n "${SSH_VIA}" ]]; then
    ssh "${SSH_VIA}" "
      set -e
      echo '${NEXUS_PASSWORD}' | docker login '${NEXUS_DOCKER_REGISTRY}' -u '${NEXUS_USER}' --password-stdin
      docker pull '${src}' || true
      docker tag '${src}' '${dest}'
      docker push '${dest}' || {
        echo 'WARN: push failed for ${dest} — seed via ctr import if airgap' >&2
      }
    "
  else
    echo "${NEXUS_PASSWORD}" | docker login "${NEXUS_DOCKER_REGISTRY}" -u "${NEXUS_USER}" --password-stdin
    docker pull "${src}" || true
    docker tag "${src}" "${dest}"
    docker push "${dest}" || log "WARN: push failed for ${dest}"
  fi
}

main() {
  log "ensure cxado-docker repo exists"
  "${ROOT}/scripts/k8s/nexus-cxado-docker-setup.sh" ${SSH_VIA:+--ssh "${SSH_VIA}"}
  local spec src dest_name
  for spec in "${IMAGES[@]}"; do
    IFS='|' read -r src dest_name <<<"${spec}"
    mirror_one "${src}" "${dest_name}"
  done
  log "done — set OSS_*_IMAGE / KANIKO_EXECUTOR_IMAGE to nexus.svo.aero:8345/cxado-docker/..."
}

main "$@"
