#!/usr/bin/env bash
# Upload local k3s airgap artifacts to Nexus k3s-releases-hosted (one-time seed from laptop).
#
# Usage:
#   ./scripts/k8s/k3s-airgap-fetch.sh                    # direct GitHub (laptop)
#   ./scripts/k8s/k3s-airgap-upload-nexus.sh              # push deploy/ansible/k3s/files/airgap/
#   ./scripts/k8s/k3s-airgap-upload-nexus.sh --ssh bbv-p30-wifi
#
# After upload, any host can: ./scripts/k8s/k3s-airgap-fetch.sh --via-nexus
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

K3S_VERSION="${K3S_VERSION:-v1.35.6+k3s1}"
ARCH="${ARCH:-amd64}"
OUT_DIR="${K3S_AIRGAP_DIR:-${ROOT}/deploy/ansible/k3s/files/airgap}"
NEXUS_API_URL="${NEXUS_API_URL:-https://nexus.svo.aero:8443}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_REPO="${NEXUS_K3S_HOSTED_REPO:-k3s-releases-hosted}"
SSH_VIA=""
[[ "${1:-}" == "--ssh" ]] && SSH_VIA="${2:-bbv-p30-wifi}"

log() { printf '[k3s-airgap-upload-nexus] %s\n' "$*"; }

if [[ -z "${NEXUS_PASSWORD:-}" ]]; then
  echo "missing NEXUS_PASSWORD in ${SECRETS}" >&2
  exit 2
fi

upload_file() {
  local file="$1" dest_name="$2"
  local dir="${K3S_VERSION}"
  log "upload ${dest_name} -> ${NEXUS_REPO}/${dir}/"
  if [[ -n "${SSH_VIA}" ]]; then
    scp "${file}" "${SSH_VIA}:/tmp/nexus-upload-${dest_name}"
    ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' -X POST \
      '${NEXUS_API_URL%/}/service/rest/v1/components?repository=${NEXUS_REPO}' \
      -F 'raw.directory=${dir}' \
      -F 'raw.asset1=@/tmp/nexus-upload-${dest_name}' \
      -F 'raw.asset1.filename=${dest_name}' \
      -w ' HTTP:%{http_code}\n'; rm -f /tmp/nexus-upload-${dest_name}"
  else
    curl -sk -u "${NEXUS_USER}:${NEXUS_PASSWORD}" -X POST \
      "${NEXUS_API_URL%/}/service/rest/v1/components?repository=${NEXUS_REPO}" \
      -F "raw.directory=${dir}" \
      -F "raw.asset1=@${file}" \
      -F "raw.asset1.filename=${dest_name}" \
      -w " HTTP:%{http_code}\n"
  fi
}

need_file() {
  local f="$1"
  if [[ ! -f "${f}" ]]; then
    echo "missing ${f} — run ./scripts/k8s/k3s-airgap-fetch.sh first" >&2
    exit 2
  fi
}

need_file "${OUT_DIR}/k3s"
need_file "${OUT_DIR}/k3s-arm64"
need_file "${OUT_DIR}/install.sh"

upload_file "${OUT_DIR}/k3s" "k3s"
upload_file "${OUT_DIR}/k3s-arm64" "k3s-arm64"
upload_file "${OUT_DIR}/install.sh" "install.sh"

IMAGES_TAR="${OUT_DIR}/k3s-airgap-images-${ARCH}.tar"
IMAGES_ZST="${OUT_DIR}/k3s-airgap-images-${ARCH}.tar.zst"
if [[ -f "${IMAGES_TAR}" ]]; then
  upload_file "${IMAGES_TAR}" "k3s-airgap-images-${ARCH}.tar"
elif [[ -f "${IMAGES_ZST}" ]]; then
  upload_file "${IMAGES_ZST}" "k3s-airgap-images-${ARCH}.tar.zst"
else
  echo "missing images tarball in ${OUT_DIR}" >&2
  exit 2
fi

log "done — fetch via: K3S_VERSION=${K3S_VERSION} ./scripts/k8s/k3s-airgap-fetch.sh --via-nexus"
