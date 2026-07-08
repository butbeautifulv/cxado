#!/usr/bin/env bash
# Create cxado-docker hosted repo in Nexus and optionally seed Kaniko executor image.
#
# Usage:
#   ./scripts/k8s/nexus-cxado-docker-setup.sh
#   ./scripts/k8s/nexus-cxado-docker-setup.sh --ssh bbv-p30-wifi
#   ./scripts/k8s/nexus-cxado-docker-setup.sh --seed-kaniko /tmp/kaniko-executor-v1.23.2.tar
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

NEXUS_API_URL="${NEXUS_API_URL:-https://nexus.svo.aero:8443}"
NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
CXADO_DOCKER_REPO="${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}"
KANIKO_VERSION="${KANIKO_EXECUTOR_VERSION:-v1.23.2}"
KANIKO_GCR="gcr.io/kaniko-project/executor:${KANIKO_VERSION}"
KANIKO_NEXUS="${NEXUS_DOCKER_REGISTRY}/${CXADO_DOCKER_REPO}/kaniko-executor:${KANIKO_VERSION}"

SSH_VIA=""
SEED_TAR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_VIA="${2:-bbv-p30-wifi}"; shift 2 ;;
    --seed-kaniko) SEED_TAR="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[nexus-cxado-docker] %s\n' "$*"; }

if [[ -z "${NEXUS_PASSWORD}" ]]; then
  echo "missing NEXUS_PASSWORD in ${SECRETS}" >&2
  exit 2
fi

nexus_curl() {
  local method="$1" path="$2" body="${3:-}"
  local url="${NEXUS_API_URL%/}${path}"
  if [[ -n "${SSH_VIA}" ]]; then
    if [[ -n "${body}" ]]; then
      ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' -X '${method}' \
        -H 'Content-Type: application/json' -d $(printf '%q' "${body}") '${url}' -w '\nHTTP:%{http_code}\n'"
    else
      ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' -X '${method}' \
        '${url}' -w '\nHTTP:%{http_code}\n'"
    fi
  else
    curl -sk -u "${NEXUS_USER}:${NEXUS_PASSWORD}" -X "${method}" \
      -H "Content-Type: application/json" \
      ${body:+-d "${body}"} \
      "${url}" -w "\nHTTP:%{http_code}\n"
  fi
}

http_code() { echo "$1" | tail -1 | sed 's/HTTP://'; }

ensure_hosted_repo() {
  local out code
  out="$(nexus_curl GET "/service/rest/v1/repositories/${CXADO_DOCKER_REPO}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  if [[ "${code}" == "200" ]]; then
    log "repo exists: ${CXADO_DOCKER_REPO}"
    return 0
  fi
  log "create hosted docker repo: ${CXADO_DOCKER_REPO}"
  local body
  body="$(cat <<EOF
{
  "name": "${CXADO_DOCKER_REPO}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": true,
    "writePolicy": "ALLOW"
  },
  "docker": {
    "v1Enabled": false,
    "forceBasicAuth": true
  }
}
EOF
)"
  out="$(nexus_curl POST "/service/rest/v1/repositories/docker/hosted" "${body}")"
  code="$(http_code "${out}")"
  if [[ "${code}" != "201" && "${code}" != "200" ]]; then
    echo "${out}" >&2
    exit 1
  fi
}

seed_kaniko_remote() {
  local host="${SSH_VIA:-bbv-p30-wifi}"
  local sudo_pw="${CXADO_OFFLINE_SUDO_PW:-}"
  log "seed kaniko executor on ${host} -> ${KANIKO_NEXUS}"
  if [[ -n "${SEED_TAR}" && -f "${SEED_TAR}" ]]; then
  scp "${SEED_TAR}" "${host}:/tmp/kaniko-executor.tar"
  else
    log "no --seed-kaniko tar; expect gcr image already loaded on ${host}"
  fi
  ssh "${host}" "NEXUS_PASSWORD='${NEXUS_PASSWORD}' NEXUS_USER='${NEXUS_USER}' \
    NEXUS_DOCKER_REGISTRY='${NEXUS_DOCKER_REGISTRY}' CXADO_DOCKER_REPO='${CXADO_DOCKER_REPO}' \
    KANIKO_GCR='${KANIKO_GCR}' KANIKO_NEXUS='${KANIKO_NEXUS}' KANIKO_VERSION='${KANIKO_VERSION}' \
    SUDO_PW='${sudo_pw}' bash -s" <<'EOS'
set -euo pipefail
sudo_run() {
  if [[ -n "${SUDO_PW:-}" ]]; then
    printf '%s\n' "${SUDO_PW}" | sudo -S -p "" "$@"
  else
    sudo "$@"
  fi
}
if [[ -f /tmp/kaniko-executor.tar ]]; then
  sudo_run docker load -i /tmp/kaniko-executor.tar
fi
if ! sudo_run docker image inspect "${KANIKO_GCR}" >/dev/null 2>&1; then
  echo "missing ${KANIKO_GCR} on host — pass --seed-kaniko from laptop" >&2
  exit 1
fi
sudo_run docker tag "${KANIKO_GCR}" "${KANIKO_NEXUS}"
sudo_run bash -c "printf '%s\n' \"\${NEXUS_PASSWORD}\" | docker login \"\${NEXUS_DOCKER_REGISTRY}\" -u \"\${NEXUS_USER}\" --password-stdin"
sudo_run docker push "${KANIKO_NEXUS}"
sudo_run docker save "${KANIKO_NEXUS}" -o /tmp/kaniko-nexus.tar
sudo_run k3s ctr images import /tmp/kaniko-nexus.tar
sudo_run k3s ctr images ls | grep -i kaniko || true
EOS
}

ensure_hosted_repo
seed_kaniko_remote
log "done — images: ${KANIKO_NEXUS}, ${NEXUS_DOCKER_REGISTRY}/${CXADO_DOCKER_REPO}/egregore:<tag>"
