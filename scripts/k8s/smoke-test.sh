#!/usr/bin/env bash
set -euo pipefail

CTX="${KUBE_CONTEXT:-kind-cxado}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"

curl_pod() {
  local ns="$1"
  local svc="$2"
  local port="$3"
  local path="$4"
  kubectl run "curl-$(date +%s)" --rm -i --restart=Never -n "$ns" --image="${SMOKE_IMAGE}" -- \
    curl -fsS -m 10 "http://${svc}:${port}${path}" >/dev/null
}

fail=0
try_curl() {
  local name="$1"
  shift
  if "$@"; then
    echo "OK  $name"
  else
    echo "FAIL $name"
    fail=1
  fi
}

try_curl "egregore-api" curl_pod cxado-app egregore-api 8080 /health
try_curl "veil-api" curl_pod veil veil-api 8090 /health || try_curl "veil-api-fallback" curl_pod veil veil-veil-api 8090 /health
try_curl "veil-mcp" curl_pod veil veil-mcp 8091 /health || try_curl "veil-mcp-fallback" curl_pod veil veil-veil-mcp 8091 /health

if curl_pod cxado-app egregore-api 8080 /catalog/agents 2>/dev/null; then
  echo "OK  egregore-catalog"
else
  echo "SKIP egregore-catalog (auth or not ready)"
fi

kubectl get pods -A | grep -E 'cxado|veil' || true
exit "$fail"
