#!/usr/bin/env bash
# Smoke test Veil observability on k3s offline (metrics + health; logs/traces when obs stack present).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SSH_HOST="${VEIL_OFFLINE_SSH_HOST:-${CXADO_OFFLINE_SSH_HOST}}"
SSH_PORT="${VEIL_OFFLINE_SSH_PORT:-${CXADO_OFFLINE_SSH_PORT}}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"

kubectl_cmd() {
  if [[ -n "$SSH_HOST" ]]; then
    ssh -p "$SSH_PORT" "$SSH_HOST" "KUBECONFIG=/home/bbv/.kube/config k3s kubectl $*"
  else
    kubectl "$@"
  fi
}

curl_pod() {
  local ns="$1" svc="$2" port="$3" path="$4"
  kubectl_cmd run "veil-curl-$(date +%s)" --rm -i --restart=Never -n "$ns" --image="${SMOKE_IMAGE}" -- \
    curl -fsS -m 15 "http://${svc}:${port}${path}" >/dev/null
}

fail=0
ok() { echo "OK  $1"; }
bad() { echo "FAIL $1"; fail=1; }

echo "=== Veil observability smoke ==="

if kubectl_cmd -n veil rollout status deploy/veil-veil-api --timeout=120s >/dev/null 2>&1; then
  ok "rollout veil-api"
else
  bad "rollout veil-api"
fi

if kubectl_cmd -n veil rollout status deploy/veil-veil-mcp --timeout=120s >/dev/null 2>&1; then
  ok "rollout veil-mcp"
else
  bad "rollout veil-mcp"
fi

if curl_pod veil veil-api 8090 /health 2>/dev/null; then ok "health veil-api (alias svc)"; else
  if curl_pod veil veil-veil-api 8090 /health 2>/dev/null; then ok "health veil-veil-api"; else bad "health veil-api"; fi
fi

if curl_pod veil veil-mcp 8091 /health 2>/dev/null; then ok "health veil-mcp (alias svc)"; else
  if curl_pod veil veil-veil-mcp 8091 /health 2>/dev/null; then ok "health veil-veil-mcp"; else bad "health veil-mcp"; fi
fi

if curl_pod veil veil-api 8090 /v1/categories 2>/dev/null; then ok "graph query /v1/categories"; else bad "graph query"; fi

echo ""
echo "Prometheus targets (manual): up{job=~\"veil-.*\"}"
echo "Grafana: Veil / Observability dashboard (veil-observability)"
echo "Cross-service trace: egregore tool call -> veil-mcp (Tempo service map)"

kubectl_cmd get pods -n veil -l 'app in (veil-api,veil-mcp)' 2>/dev/null || true
exit "$fail"
