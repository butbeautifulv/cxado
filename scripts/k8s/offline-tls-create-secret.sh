#!/usr/bin/env bash
# Generate self-signed TLS cert for offline access (localhost + node LAN IP) and create k8s secret.
#
# Output (gitignored):
#   deploy/.secrets/tls/tls.crt
#   deploy/.secrets/tls/tls.key
#
# Usage:
#   ./scripts/k8s/offline-tls-create-secret.sh [--certs-only] [--force]
#
# Env:
#   CXADO_NODE_IP (default: 10.8.185.15)
#   CXADO_NODE_HOSTNAME (default: bbv-p30-k44)
#   CXADO_TLS_SAN_DNS_EXTRA (optional comma-separated extra DNS names)
#   CXADO_TLS_SAN_IP_EXTRA (optional comma-separated extra IPs)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
NS="${CXADO_TLS_NS:-cxado-edge}"
TLS_DIR="${CXADO_TLS_DIR:-${ROOT}/deploy/.secrets/tls}"
SECRET_NAME="${CXADO_TLS_SECRET_NAME:-cxado-offline-tls}"
NODE_IP="${CXADO_NODE_IP}"
NODE_HOSTNAME="${CXADO_NODE_HOSTNAME:-bbv-p30-k44}"

CERTS_ONLY=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --certs-only) CERTS_ONLY=1 ;;
    --force) FORCE=1 ;;
  esac
done

mkdir -p "${TLS_DIR}"

build_san() {
  local san="DNS:localhost,DNS:cxado.local,DNS:${NODE_HOSTNAME}"
  if [[ -n "${CXADO_TLS_SAN_DNS_EXTRA:-}" ]]; then
    IFS=',' read -ra extra_dns <<<"${CXADO_TLS_SAN_DNS_EXTRA}"
    for d in "${extra_dns[@]}"; do
      d="$(echo "$d" | xargs)"
      [[ -n "$d" ]] && san="${san},DNS:${d}"
    done
  fi
  san="${san},IP:127.0.0.1,IP:${NODE_IP}"
  if [[ -n "${CXADO_TLS_SAN_IP_EXTRA:-}" ]]; then
    IFS=',' read -ra extra_ips <<<"${CXADO_TLS_SAN_IP_EXTRA}"
    for ip in "${extra_ips[@]}"; do
      ip="$(echo "$ip" | xargs)"
      [[ -n "$ip" ]] && san="${san},IP:${ip}"
    done
  fi
  printf '%s' "$san"
}

if [[ "${FORCE}" -eq 1 ]]; then
  rm -f "${TLS_DIR}/tls.crt" "${TLS_DIR}/tls.key"
fi

if [[ ! -f "${TLS_DIR}/tls.crt" || ! -f "${TLS_DIR}/tls.key" ]]; then
  SAN="$(build_san)"
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "${TLS_DIR}/tls.key" \
    -out "${TLS_DIR}/tls.crt" \
    -subj "/CN=${NODE_IP}/O=cxado-offline" \
    -addext "subjectAltName=${SAN}"
  chmod 600 "${TLS_DIR}/tls.key"
  chmod 644 "${TLS_DIR}/tls.crt"
  echo "generated cert SAN=${SAN}"
fi

if [[ "${CERTS_ONLY}" -eq 1 ]]; then
  echo "wrote ${TLS_DIR}/tls.crt"
  exit 0
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found; generated certs only at ${TLS_DIR}" >&2
  exit 0
fi

kubectl get ns "${NS}" >/dev/null 2>&1 || kubectl create ns "${NS}"

kubectl -n "${NS}" delete secret "${SECRET_NAME}" >/dev/null 2>&1 || true
kubectl -n "${NS}" create secret tls "${SECRET_NAME}" \
  --cert="${TLS_DIR}/tls.crt" \
  --key="${TLS_DIR}/tls.key"

echo "tls secret ${SECRET_NAME} refreshed in ${NS}"
echo "cert: ${TLS_DIR}/tls.crt (import into browser Authorities to skip warnings)"
