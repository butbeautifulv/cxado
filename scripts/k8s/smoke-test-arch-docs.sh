#!/usr/bin/env bash
# Smoke test architecture docs site on k3s offline TLS gateway.
#
# Usage:
#   CXADO_ARCH_DOCS_HOST=10.8.185.15 ./scripts/k8s/smoke-test-arch-docs.sh
#   CXADO_ARCH_DOCS_INSECURE=1 ./scripts/k8s/smoke-test-arch-docs.sh https://10.8.185.15:30080
set -euo pipefail

HOST="${CXADO_ARCH_DOCS_HOST:-10.8.185.15}"
PORT="${CXADO_ARCH_DOCS_PORT:-30080}"
BASE_URL="${1:-https://${HOST}:${PORT}}"
CURL_OPTS=(-fsS --connect-timeout 10)

if [[ "${CXADO_ARCH_DOCS_INSECURE:-}" == "1" ]]; then
  CURL_OPTS+=(-k)
fi

echo "[smoke] GET ${BASE_URL}/"
body="$(curl "${CURL_OPTS[@]}" "${BASE_URL}/")"
echo "${body}" | grep -q "cxado — архитектура платформы" || {
  echo "error: index.html title not found" >&2
  exit 1
}

echo "[smoke] GET ${BASE_URL}/js/mermaid.min.js"
curl "${CURL_OPTS[@]}" -o /dev/null "${BASE_URL}/js/mermaid.min.js"

echo "[smoke] GET ${BASE_URL}/diagrams/ecosystem.mmd"
curl "${CURL_OPTS[@]}" "${BASE_URL}/diagrams/ecosystem.mmd" | grep -q "flowchart TB"

echo "[smoke] GET ${BASE_URL}/css/site.css"
curl "${CURL_OPTS[@]}" -o /dev/null "${BASE_URL}/css/site.css"

echo "[smoke] OK — architecture site reachable"
