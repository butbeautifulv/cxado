#!/usr/bin/env bash
# Mirror Fabrica CI images into cxado-docker via Nexus proxies only (no upstream internet).
#
# Nexus paths:
#   nexus.svo.aero:8345  — Docker Hub (Docker-proxy)
#   nexus.svo.aero:8374  — Docker-SEPS group (gcr.io, ghcr.io, …)
#
# Usage:
#   ./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi
#   ./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi --dry-run
#   ./scripts/gitlab/mirror-fabrica-ci-images.sh --ssh bbv-p30-wifi --verify-only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=deploy/registry.defaults.env
[[ -f "${ROOT}/deploy/registry.defaults.env" ]] && source "${ROOT}/deploy/registry.defaults.env"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
NEXUS_DOCKER_GROUP_REGISTRY="${NEXUS_DOCKER_GROUP_REGISTRY:-nexus.svo.aero:8374}"
CXADO_REPO="${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
KANIKO_VERSION="${KANIKO_EXECUTOR_VERSION:-v1.23.2}"
RUNNER_HELPER_VERSION="${GITLAB_RUNNER_HELPER_VERSION:-x86_64-v19.1.1}"
DEFECTDOJO_VERSION="${DEFECTDOJO_VERSION:-2.50.0}"
CHECKOV_VERSION="${OSS_CHECKOV_VERSION:-3.2.449}"
SSH_VIA=""
DRY_RUN=false
VERIFY_ONLY=false

log() { printf '[mirror-fabrica-ci] %s\n' "$*"; }
warn() { printf '[mirror-fabrica-ci] WARN: %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_VIA="${2:-bbv-p30-wifi}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verify-only) VERIFY_ONLY=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "${SSH_VIA}" ]] || { echo "requires --ssh <host> (corp node with docker + k3s)" >&2; exit 2; }
[[ -n "${NEXUS_PASSWORD}" ]] || { echo "missing NEXUS_PASSWORD in ${SECRETS}" >&2; exit 2; }

HUB="${NEXUS_DOCKER_REGISTRY}"
GROUP="${NEXUS_DOCKER_GROUP_REGISTRY}"

# nexus_pull_ref|dest_name — keep dest names in sync with config/oss-tool-versions.yaml
IMAGES=(
  "${GROUP}/kaniko-project/executor:${KANIKO_VERSION}|kaniko-executor:${KANIKO_VERSION}"
  "${HUB}/returntocorp/semgrep:1.117.0|semgrep:1.117.0"
  "${HUB}/anchore/syft:v1.20.0|syft:v1.20.0"
  "${HUB}/aquasec/trivy:0.63.0|trivy:0.63.0"
  "${GROUP}/gitleaks/gitleaks:v8.22.1|gitleaks:v8.22.1"
  "${HUB}/hadolint/hadolint:v2.12.0-alpine|hadolint:v2.12.0-alpine"
  "${HUB}/bridgecrew/checkov:${CHECKOV_VERSION}|checkov:${CHECKOV_VERSION}"
  "${GROUP}/openpolicyagent/conftest:v0.56.0|conftest:v0.56.0"
  "${HUB}/alpine/helm:3.17.2|helm:3.17.2"
  "${HUB}/python:3.11.11-slim-bookworm|python:3.11.11-slim-bookworm"
  "${HUB}/alpine:3.20.3|alpine:3.20.3"
  "${HUB}/rancher/kubectl:v1.32.2|kubectl:1.32.2"
  "${GROUP}/projectsigstore/cosign:v2.4.0|cosign:v2.4.0"
  "${HUB}/library/postgres:16|postgres:16"
  "${HUB}/library/redis:7|redis:7"
  "${HUB}/defectdojo/defectdojo-django:${DEFECTDOJO_VERSION}|defectdojo-django:${DEFECTDOJO_VERSION}"
  "${HUB}/defectdojo/defectdojo-nginx:${DEFECTDOJO_VERSION}|defectdojo-nginx:${DEFECTDOJO_VERSION}"
  "${HUB}/oven/bun:1-alpine|oven-bun:1-alpine"
  "${HUB}/library/golang:1.25-bookworm|golang-1.25-bookworm"
  "${GROUP}/distroless/static-debian12:nonroot|distroless-static-debian12:nonroot"
)

# Not cached in Nexus gitlab-hub proxy — verify-only if already imported to containerd
OPTIONAL_VERIFY=(
  "gitlab-runner-helper:${RUNNER_HELPER_VERSION}"
)

ensure_docker_nexus_tls() {
  log "ensure docker insecure-registries for ${HUB} and ${GROUP}"
  if [[ "${DRY_RUN}" == true ]]; then
    return 0
  fi
  ssh "${SSH_VIA}" env \
    "CXADO_OFFLINE_SUDO_PW=${CXADO_OFFLINE_SUDO_PW:-}" \
    "NEXUS_DOCKER_REGISTRY=${HUB}" \
    "NEXUS_DOCKER_GROUP_REGISTRY=${GROUP}" \
    bash -s <<'EOS' || warn "docker TLS setup skipped"
set -euo pipefail
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
HUB="${NEXUS_DOCKER_REGISTRY}"
GROUP="${NEXUS_DOCKER_GROUP_REGISTRY}"
sudo_run() {
  if [[ -n "${SUDO_PW}" ]]; then
    printf '%s\n' "${SUDO_PW}" | sudo -S -p '' "$@"
  else
    sudo "$@"
  fi
}
if ! command -v docker >/dev/null 2>&1; then
  echo 'docker not installed — skip TLS setup' >&2
  exit 0
fi
TMP=$(mktemp)
cat >"${TMP}" <<DOCKERJSON
{
  "insecure-registries": ["${HUB}", "${GROUP}"],
  "registry-mirrors": ["https://${HUB}"]
}
DOCKERJSON
sudo_run cp "${TMP}" /etc/docker/daemon.json
rm -f "${TMP}"
for REG in "${HUB}" "${GROUP}"; do
  sudo_run mkdir -p "/etc/docker/certs.d/${REG}"
  if openssl s_client -connect "${REG}" -servername nexus.svo.aero </dev/null 2>/dev/null \
    | openssl x509 -outform PEM > "/tmp/nexus-${REG//[:.]/_}.crt" 2>/dev/null \
    && [[ -s "/tmp/nexus-${REG//[:.]/_}.crt" ]]; then
    sudo_run cp "/tmp/nexus-${REG//[:.]/_}.crt" "/etc/docker/certs.d/${REG}/ca.crt"
  fi
done
sudo_run systemctl restart docker || true
sleep 2
EOS
}

mirror_one() {
  local nexus_src="$1" dest_name="$2"
  local dest="${HUB}/${CXADO_REPO}/${dest_name}"
  local tar_base="mirror-$(echo "${dest_name}" | tr '/:' '_').tar"
  log "mirror ${nexus_src} -> ${dest}"
  if [[ "${DRY_RUN}" == true ]]; then
    return 0
  fi
  ssh "${SSH_VIA}" env \
    "CXADO_OFFLINE_SUDO_PW=${CXADO_OFFLINE_SUDO_PW:-}" \
    "NEXUS_PASSWORD=${NEXUS_PASSWORD}" \
    "NEXUS_USER=${NEXUS_USER}" \
    "MIRROR_HUB=${HUB}" \
    "MIRROR_GROUP=${GROUP}" \
    "MIRROR_NEXUS_SRC=${nexus_src}" \
    "MIRROR_DEST=${dest}" \
    "MIRROR_TAR=/tmp/${tar_base}" \
  bash -s <<'EOS'
set -euo pipefail
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
sudo_run() {
  if [[ -n "${SUDO_PW}" ]]; then
    printf '%s\n' "${SUDO_PW}" | sudo -S -p '' "$@"
  else
    sudo "$@"
  fi
}
printf '%s\n' "${NEXUS_PASSWORD}" | docker login "${MIRROR_HUB}" -u "${NEXUS_USER}" --password-stdin
printf '%s\n' "${NEXUS_PASSWORD}" | docker login "${MIRROR_GROUP}" -u "${NEXUS_USER}" --password-stdin
DEST_TAG="${MIRROR_DEST##*/}"
if sudo_run k3s ctr images ls 2>/dev/null | grep -Fq "${DEST_TAG}"; then
  echo "present: ${MIRROR_DEST}"
  exit 0
fi
docker pull "${MIRROR_NEXUS_SRC}"
docker tag "${MIRROR_NEXUS_SRC}" "${MIRROR_DEST}"
docker save "${MIRROR_DEST}" -o "${MIRROR_TAR}"
sudo_run k3s ctr images import "${MIRROR_TAR}"
rm -f "${MIRROR_TAR}"
# hosted push often fails (TLS); local ctr import is what k3s job pods need
docker push "${MIRROR_DEST}" >/dev/null 2>&1 || true
EOS
}

verify_ctr_tag() {
  local dest_name="$1"
  log "verify containerd has ${dest_name}"
  if [[ "${DRY_RUN}" == true ]]; then
    return 0
  fi
  ssh "${SSH_VIA}" env "CXADO_OFFLINE_SUDO_PW=${CXADO_OFFLINE_SUDO_PW:-}" bash -s <<EOS
set -euo pipefail
SUDO_PW="\${CXADO_OFFLINE_SUDO_PW:-}"
sudo_run() {
  if [[ -n "\${SUDO_PW}" ]]; then
    printf '%s\n' "\${SUDO_PW}" | sudo -S -p '' "\$@"
  else
    sudo "\$@"
  fi
}
if sudo_run k3s ctr images ls | grep -Fq '${dest_name}'; then
  echo "ok: ${dest_name}"
  exit 0
fi
exit 1
EOS
}

verify_trivy_vulndb() {
  log "verify Trivy vulndb via Nexus ${GROUP}/aquasecurity/trivy-db"
  if [[ "${DRY_RUN}" == true ]]; then
    return 0
  fi
  if ! ssh "${SSH_VIA}" env \
    "NEXUS_PASSWORD=${NEXUS_PASSWORD}" \
    "NEXUS_USER=${NEXUS_USER}" \
    "MIRROR_HUB=${HUB}" \
    "MIRROR_GROUP=${GROUP}" \
    "TRIVY_IMAGE=${HUB}/${CXADO_REPO}/trivy:0.63.0" \
  bash -s <<'EOS'
set -euo pipefail
printf '%s\n' "${NEXUS_PASSWORD}" | docker login "${MIRROR_HUB}" -u "${NEXUS_USER}" --password-stdin
printf '%s\n' "${NEXUS_PASSWORD}" | docker login "${MIRROR_GROUP}" -u "${NEXUS_USER}" --password-stdin
CACHE="/tmp/trivy-vulndb-verify-$$"
mkdir -p "${CACHE}"
export TRIVY_DB_REPOSITORY="${MIRROR_GROUP}/aquasecurity/trivy-db"
export TRIVY_JAVA_DB_REPOSITORY="${MIRROR_GROUP}/aquasecurity/trivy-java-db"
if [ -f /etc/docker/certs.d/"${MIRROR_GROUP}"/ca.crt ]; then
  export SSL_CERT_FILE="/etc/docker/certs.d/${MIRROR_GROUP}/ca.crt"
fi
docker run --rm \
  -e TRIVY_DB_REPOSITORY -e TRIVY_JAVA_DB_REPOSITORY -e SSL_CERT_FILE \
  -v "${CACHE}:/tmp/trivy-cache" \
  "${TRIVY_IMAGE}" \
  trivy image --download-db-only --cache-dir /tmp/trivy-cache
rm -rf "${CACHE}"
echo "ok: trivy vulndb via ${TRIVY_DB_REPOSITORY}"
EOS
  then
    warn "Trivy vulndb download failed — check Nexus 8374 proxy for ghcr.io/aquasecurity/trivy-db"
    return 1
  fi
}

main() {
  if [[ "${VERIFY_ONLY}" != true ]]; then
    log "ensure cxado-docker repo exists"
    "${ROOT}/scripts/k8s/nexus-cxado-docker-setup.sh" --ssh "${SSH_VIA}" --repo-only
    ensure_docker_nexus_tls
    local spec nexus_src dest_name
    for spec in "${IMAGES[@]}"; do
      IFS='|' read -r nexus_src dest_name <<<"${spec}"
      mirror_one "${nexus_src}" "${dest_name}" || warn "mirror failed for ${dest_name}"
    done
  fi

  local spec dest_name tag failed=0
  for spec in "${IMAGES[@]}"; do
    IFS='|' read -r _ dest_name <<<"${spec}"
    if ! verify_ctr_tag "${dest_name}"; then
      warn "verify failed: ${dest_name}"
      failed=$((failed + 1))
    fi
  done
  for tag in "${OPTIONAL_VERIFY[@]}"; do
    if ! verify_ctr_tag "${tag}"; then
      warn "optional image missing in containerd: ${tag} (not in Nexus gitlab-hub cache — ask Nexus admin or import once)"
      failed=$((failed + 1))
    fi
  done

  if [[ "${failed}" -gt 0 ]]; then
    warn "${failed} image(s) missing — run ansible playbooks/ci-images.yml on all nodes"
    exit 1
  fi
  verify_trivy_vulndb || warn "trivy vulndb verify failed (CI jobs need TRIVY_DB_REPOSITORY)"
  log "done — ${HUB}/${CXADO_REPO}/... available in containerd"
}

main "$@"
