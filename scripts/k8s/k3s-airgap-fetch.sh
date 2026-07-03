#!/usr/bin/env bash
# Download offline air-gap artifacts for k3s + helm (run on laptop with internet).
#
# Usage:
#   ./scripts/k8s/k3s-airgap-fetch.sh
#   K3S_VERSION=v1.35.0+k3s1 HELM_VERSION=v4.1.0 ARCH=amd64 ./scripts/k8s/k3s-airgap-fetch.sh
#
# Output directory (default):
#   deploy/ansible/k3s/files/airgap/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
K3S_VERSION="${K3S_VERSION:-v1.35.0+k3s1}"
HELM_VERSION="${HELM_VERSION:-v4.1.0}"
ARCH="${ARCH:-amd64}"
OUT_DIR="${K3S_AIRGAP_DIR:-${ROOT}/deploy/ansible/k3s/files/airgap}"

K3S_BASE="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}"
HELM_BASE="https://get.helm.sh"

mkdir -p "$OUT_DIR"

fetch() {
  local url="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    printf '[airgap-fetch] skip (exists): %s\n' "$dest"
    return 0
  fi
  printf '[airgap-fetch] download: %s\n' "$url"
  curl -fsSL "$url" -o "$dest"
}

chmod_bin() {
  chmod +x "$1"
}

fetch "${K3S_BASE}/k3s" "${OUT_DIR}/k3s"
fetch "${K3S_BASE}/k3s-arm64" "${OUT_DIR}/k3s-arm64"
fetch "${K3S_BASE}/install.sh" "${OUT_DIR}/install.sh"
chmod_bin "${OUT_DIR}/k3s"
chmod_bin "${OUT_DIR}/k3s-arm64"
chmod_bin "${OUT_DIR}/install.sh"

IMAGES_TAR="${OUT_DIR}/k3s-airgap-images-${ARCH}.tar"
IMAGES_ZST="${OUT_DIR}/k3s-airgap-images-${ARCH}.tar.zst"
if [[ ! -f "$IMAGES_TAR" ]]; then
  if ! curl -fsSL "${K3S_BASE}/k3s-airgap-images-${ARCH}.tar" -o "$IMAGES_TAR" 2>/dev/null; then
    fetch "${K3S_BASE}/k3s-airgap-images-${ARCH}.tar.zst" "$IMAGES_ZST"
  fi
else
  printf '[airgap-fetch] skip (exists): %s\n' "$IMAGES_TAR"
fi

fetch "${HELM_BASE}/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
  "${OUT_DIR}/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"

printf '[airgap-fetch] done -> %s\n' "$OUT_DIR"
ls -lh "$OUT_DIR"
