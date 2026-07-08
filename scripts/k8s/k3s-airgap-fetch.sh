#!/usr/bin/env bash
# Download offline air-gap artifacts for k3s + helm.
#
# Usage:
#   ./scripts/k8s/k3s-airgap-fetch.sh                         # direct GitHub/helm.sh (laptop)
#   ./scripts/k8s/k3s-airgap-fetch.sh --via-nexus             # corp Nexus (P30 / VM / jump)
#   ./scripts/k8s/k3s-airgap-fetch.sh --via-nexus --ssh bbv-p30-wifi
#   K3S_VERSION=v1.35.6+k3s1 HELM_VERSION=v4.1.0 ./scripts/k8s/k3s-airgap-fetch.sh
#
# Nexus repos (add-only, see nexus-k3s-repos-setup.sh):
#   helm-get-proxy       — get.helm.sh binaries
#   k3s-releases-proxy   — GitHub releases via github.com + routing rule
#   k3s-get-proxy        — get.k3s.io install script
#   k3s-releases-hosted  — optional manual cache (seed: k3s-airgap-upload-nexus.sh)
#
# Output: deploy/ansible/k3s/files/airgap/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

K3S_VERSION="${K3S_VERSION:-v1.35.6+k3s1}"
HELM_VERSION="${HELM_VERSION:-v4.1.0}"
ARCH="${ARCH:-amd64}"
OUT_DIR="${K3S_AIRGAP_DIR:-${ROOT}/deploy/ansible/k3s/files/airgap}"
VIA_NEXUS=false
SSH_VIA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --via-nexus) VIA_NEXUS=true; shift ;;
    --ssh) SSH_VIA="${2:-bbv-p30-wifi}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

NEXUS_API_URL="${NEXUS_API_URL:-https://nexus.svo.aero:8443}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_HELM_REPO="${NEXUS_HELM_PROXY_REPO:-helm-get-proxy}"
NEXUS_K3S_REPO="${NEXUS_K3S_PROXY_REPO:-k3s-releases-proxy}"
NEXUS_K3S_GET_REPO="${NEXUS_K3S_GET_PROXY_REPO:-k3s-get-proxy}"

K3S_BASE="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}"
HELM_BASE="https://get.helm.sh"
K3S_INSTALL_BASE="https://get.k3s.io"

urlencode_version() {
  printf '%s' "$1" | sed 's/+/%2B/g'
}

K3S_VERSION_ENC="$(urlencode_version "${K3S_VERSION}")"
NEXUS_K3S_BASE="${NEXUS_API_URL%/}/repository/${NEXUS_K3S_REPO}/k3s-io/k3s/releases/download/${K3S_VERSION_ENC}"
NEXUS_K3S_INSTALL_BASE="${NEXUS_API_URL%/}/repository/${NEXUS_K3S_GET_REPO}"
NEXUS_HELM_BASE="${NEXUS_API_URL%/}/repository/${NEXUS_HELM_REPO}"

mkdir -p "${OUT_DIR}"

log() { printf '[airgap-fetch] %s\n' "$*"; }

curl_fetch() {
  local url="$1" dest="$2"
  if [[ -f "${dest}" ]]; then
    log "skip (exists): ${dest}"
    return 0
  fi
  log "download: ${url}"
  local curl_auth=()
  local curl_tls=()
  if [[ "${VIA_NEXUS}" == true ]]; then
    curl_auth=(-u "${NEXUS_USER}:${NEXUS_PASSWORD}")
    curl_tls=(-k)
  fi
  if [[ -n "${SSH_VIA}" ]]; then
    local remote_curl="curl -fsSL"
    if [[ "${VIA_NEXUS}" == true ]]; then
      remote_curl="curl -fsSLk -u '${NEXUS_USER}:${NEXUS_PASSWORD}'"
    fi
    ssh "${SSH_VIA}" "${remote_curl} '${url}' -o /tmp/airgap-dl-\$(basename '${dest}')"
    scp "${SSH_VIA}:/tmp/airgap-dl-$(basename "${dest}")" "${dest}"
    ssh "${SSH_VIA}" "rm -f /tmp/airgap-dl-$(basename "${dest}")"
  elif [[ "${VIA_NEXUS}" == true ]]; then
    curl -fsSL "${curl_tls[@]}" "${curl_auth[@]}" "${url}" -o "${dest}"
  else
    curl -fsSL "${url}" -o "${dest}"
  fi
}

chmod_bin() { chmod +x "$1"; }

if [[ "${VIA_NEXUS}" == true ]]; then
  if [[ -z "${NEXUS_PASSWORD:-}" ]]; then
    echo "missing NEXUS_PASSWORD for --via-nexus" >&2
    exit 2
  fi
  log "source=nexus (${NEXUS_API_URL}) version=${K3S_VERSION}"
  K3S_SRC="${NEXUS_K3S_BASE}"
  K3S_INSTALL_SRC="${NEXUS_K3S_INSTALL_BASE}"
  HELM_SRC="${NEXUS_HELM_BASE}"
else
  log "source=upstream github/helm.sh version=${K3S_VERSION}"
  K3S_SRC="${K3S_BASE}"
  K3S_INSTALL_SRC="${K3S_INSTALL_BASE}"
  HELM_SRC="${HELM_BASE}"
fi

curl_fetch "${K3S_SRC}/k3s" "${OUT_DIR}/k3s"
curl_fetch "${K3S_SRC}/k3s-arm64" "${OUT_DIR}/k3s-arm64"
curl_fetch "${K3S_INSTALL_SRC}/" "${OUT_DIR}/install.sh"
chmod_bin "${OUT_DIR}/k3s"
chmod_bin "${OUT_DIR}/k3s-arm64"
chmod_bin "${OUT_DIR}/install.sh"

IMAGES_TAR="${OUT_DIR}/k3s-airgap-images-${ARCH}.tar"
IMAGES_ZST="${OUT_DIR}/k3s-airgap-images-${ARCH}.tar.zst"
if [[ ! -f "${IMAGES_TAR}" ]]; then
  if ! curl_fetch "${K3S_SRC}/k3s-airgap-images-${ARCH}.tar" "${IMAGES_TAR}" 2>/dev/null; then
    curl_fetch "${K3S_SRC}/k3s-airgap-images-${ARCH}.tar.zst" "${IMAGES_ZST}"
  fi
else
  log "skip (exists): ${IMAGES_TAR}"
fi

curl_fetch "${HELM_SRC}/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
  "${OUT_DIR}/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"

log "done -> ${OUT_DIR}"
ls -lh "${OUT_DIR}"
