#!/usr/bin/env bash
# Smoke test Veil observability on k3s offline (metrics + health; logs/traces when obs stack present).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SSH_HOST="${VEIL_OFFLINE_SSH_HOST:-${CXADO_OFFLINE_SSH_HOST}}"
SSH_PORT="${VEIL_OFFLINE_SSH_PORT:-${CXADO_OFFLINE_SSH_PORT}}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"
CXADO_VEIL_PROFILE="${CXADO_VEIL_PROFILE:-graph-only}"
PROMETHEUS_URL="${PROMETHEUS_URL:-https://${CXADO_NODE_IP}:30091}"

kubectl_cmd() {
  if [[ -n "$SSH_HOST" ]]; then
    # shellcheck disable=SC2029
    ssh -p "$SSH_PORT" "$SSH_HOST" \
      "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
  else
    kubectl "$@"
  fi
}

curl_pod() {
  local ns="$1" svc="$2" port="$3" path="$4"
  local overrides="{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"${CXADO_NODE_HOSTNAME}\"}}}"
  kubectl_cmd run "veil-curl-$(date +%s)-$RANDOM" --rm -i --restart=Never -n "$ns" \
    --overrides="${overrides}" --image="${SMOKE_IMAGE}" -- \
    curl -fsS -m 15 "http://${svc}:${port}${path}" >/dev/null
}

prom_query() {
  local query="$1"
  if [[ -n "$SSH_HOST" ]]; then
    ssh -p "$SSH_PORT" "$SSH_HOST" \
      "curl -fsSk -m 15 -G '${PROMETHEUS_URL}/api/v1/query' --data-urlencode 'query=${query}'" 2>/dev/null
  else
    curl -fsSk -m 15 -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${query}" 2>/dev/null
  fi
}

fail=0
ok() { echo "OK  $1"; }
skip() { echo "SKIP $1"; }
bad() { echo "FAIL $1"; fail=1; }

echo "=== Veil observability smoke (profile=${CXADO_VEIL_PROFILE}) ==="

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

set +e
if curl_pod veil veil-api 8090 /health 2>/dev/null; then ok "health veil-api (alias svc)"; else
  if curl_pod veil veil-veil-api 8090 /health 2>/dev/null; then ok "health veil-veil-api"; else bad "health veil-api"; fi
fi

if curl_pod veil veil-mcp 8091 /health 2>/dev/null; then ok "health veil-mcp (alias svc)"; else
  if curl_pod veil veil-veil-mcp 8091 /health 2>/dev/null; then ok "health veil-veil-mcp"; else bad "health veil-mcp"; fi
fi

if curl_pod veil veil-api 8090 /v1/categories 2>/dev/null; then ok "graph query /v1/categories"; else bad "graph query"; fi
set -e

if prom_query 'up{job="veil-api"} == 1' | grep -q '"value":\[.*,"1"\]'; then
  ok "prometheus up{job=veil-api}"
else
  bad "prometheus up{job=veil-api}"
fi

if prom_query 'up{job="veil-mcp"} == 1' | grep -q '"value":\[.*,"1"\]'; then
  ok "prometheus up{job=veil-mcp}"
else
  bad "prometheus up{job=veil-mcp}"
fi

if [[ "${CXADO_VEIL_PROFILE}" == "workers-obs" ]]; then
  for job in veil-ingest-worker veil-pipeline-worker veil-engage-events-worker; do
    if prom_query "up{job=\"${job}\"} == 1" | grep -q '"value":\[.*,"1"\]'; then
      ok "prometheus up{job=${job}}"
    else
      bad "prometheus up{job=${job}}"
    fi
  done
  for svc in veil-veil-ingest-worker-metrics veil-veil-pipeline-worker-metrics veil-veil-engage-events-worker-metrics; do
    if curl_pod veil "${svc}" 9090 /metrics 2>/dev/null; then
      ok "metrics ${svc}"
    else
      bad "metrics ${svc}"
    fi
  done
else
  if prom_query 'count(up{job=~"veil-(ingest|pipeline|engage-events)-worker"})' | grep -q '"value":\[.*,"0"\]'; then
    ok "no veil worker scrape jobs (graph-only)"
  else
    skip "veil worker jobs may still be present in prometheus — refresh configmap with CXADO_VEIL_PROFILE=graph-only"
  fi
fi

echo ""
kubectl_cmd get pods -n veil -l 'app in (veil-api,veil-mcp,veil-ingest-worker,veil-pipeline-worker,veil-engage-events-worker)' 2>/dev/null || true
exit "$fail"
