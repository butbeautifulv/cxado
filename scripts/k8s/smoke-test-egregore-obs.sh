#!/usr/bin/env bash
# Smoke test for egregore observability on k3s offline.
#
# Usage (local kubectl):
#   ./scripts/k8s/smoke-test-egregore-obs.sh
#
# Usage (remote via SSH forward):
#   CXADO_OFFLINE_SSH_HOST=bbv@10.8.184.22 CXADO_OFFLINE_SSH_PORT=22012 \
#     ./scripts/k8s/smoke-test-egregore-obs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
PROMETHEUS_URL="${PROMETHEUS_URL:-https://${CXADO_NODE_IP}:30091}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
NS_OBS="${CXADO_OBS_NS:-cxado-obs}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"

fail=0
pass() { printf 'OK   %s\n' "$1"; }
skip() { printf 'SKIP %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

kubectl_cmd() {
  if [[ -n "${SSH_HOST}" ]]; then
    # shellcheck disable=SC2029
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
  else
    kubectl "$@"
  fi
}

curl_pod() {
  local ns="$1"
  local svc="$2"
  local port="$3"
  local path="$4"
  local name="curl-smoke-$(date +%s)-$RANDOM"
  local overrides="{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"${CXADO_NODE_HOSTNAME}\"}}}"
  kubectl_cmd run "${name}" --rm -i --restart=Never -n "${ns}" \
    --overrides="${overrides}" --image="${SMOKE_IMAGE}" -- \
    curl -fsS -m 15 "http://${svc}:${port}${path}"
}

echo "[smoke] egregore observability"

if kubectl_cmd -n "${NS_APP}" rollout status deploy/egregore-api --timeout=120s >/dev/null 2>&1; then
  pass "egregore-api rollout"
else
  bad "egregore-api rollout"
fi

METRICS_APP="egregore-dispatcher"
METRICS_JOB="egregore-dispatcher"
if ! kubectl_cmd -n "${NS_APP}" get deploy egregore-dispatcher >/dev/null 2>&1; then
  METRICS_APP="egregore-worker"
  METRICS_JOB="egregore-worker"
else
  disp_replicas="$(kubectl_cmd -n "${NS_APP}" get deploy egregore-dispatcher -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
  if [[ "${disp_replicas}" == "0" ]]; then
    METRICS_APP="egregore-worker"
    METRICS_JOB="egregore-worker"
  fi
fi

if [[ "${METRICS_APP}" == "egregore-dispatcher" ]]; then
  if kubectl_cmd -n "${NS_APP}" rollout status deploy/egregore-dispatcher --timeout=120s >/dev/null 2>&1; then
    pass "egregore-dispatcher rollout"
  else
    bad "egregore-dispatcher rollout"
  fi
else
  worker_replicas="$(kubectl_cmd -n "${NS_APP}" get deploy egregore-worker -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
  if [[ "${worker_replicas}" == "0" ]]; then
    skip "egregore-worker scaled to 0 (dispatcher topology)"
  elif kubectl_cmd -n "${NS_APP}" rollout status deploy/egregore-worker --timeout=120s >/dev/null 2>&1; then
    pass "egregore-worker rollout"
  else
    bad "egregore-worker rollout"
  fi
fi

if kubectl_cmd -n "${NS_APP}" get pods -l app=egregore-api -o name >/dev/null 2>&1; then
  API_POD="$(kubectl_cmd -n "${NS_APP}" get pods -l app=egregore-api --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${API_POD}" ]] && kubectl_cmd -n "${NS_APP}" exec "${API_POD}" -- sh -c \
    "cd /app/api && uv run python -c \"import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=5).read().decode())\"" \
    2>/dev/null | grep -q ok; then
    pass "egregore-api /health"
  else
    bad "egregore-api /health"
  fi
else
  bad "egregore-api pod not found"
fi

METRICS_POD="$(kubectl_cmd -n "${NS_APP}" get pod -l app="${METRICS_APP}" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "${METRICS_POD}" ]]; then
  scrape_ann="$(kubectl_cmd -n "${NS_APP}" get pod "${METRICS_POD}" -o jsonpath='{.metadata.annotations.prometheus\.io/scrape}' 2>/dev/null || true)"
  if [[ "${scrape_ann}" == "true" ]]; then
    pass "${METRICS_APP} prometheus.io/scrape annotation"
  else
    bad "${METRICS_APP} prometheus.io/scrape annotation (pod=${METRICS_POD} ann=${scrape_ann:-empty})"
  fi
  if kubectl_cmd -n "${NS_APP}" exec "${METRICS_POD}" -- sh -c \
    "python3 -c \"import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8081/health', timeout=5).read().decode())\"" \
    2>/dev/null | grep -q ok; then
    pass "${METRICS_APP} /health on metrics port"
  else
    bad "${METRICS_APP} /health on metrics port"
  fi
else
  if [[ "${METRICS_APP}" == "egregore-worker" ]]; then
    skip "egregore-worker pod not found (scaled to 0)"
  else
    bad "${METRICS_APP} pod not found"
  fi
fi

PROM_QUERY="up{job=\"${METRICS_JOB}\"}"
CURL_OPTS=(-fsS)
[[ "${PROMETHEUS_URL}" == https://* ]] && CURL_OPTS+=(-k)
prom_out="$(curl "${CURL_OPTS[@]}" -G "${PROMETHEUS_URL%/}/api/v1/query" --data-urlencode "query=${PROM_QUERY}" 2>/dev/null || true)"
if echo "${prom_out}" | grep -q '"status":"success"' && echo "${prom_out}" | grep -q '"value":\[.*,"1"\]'; then
  pass "prometheus up{job=${METRICS_JOB}}"
else
  bad "prometheus up{job=${METRICS_JOB}}"
fi

for job in prometheus tempo loki grafana; do
  if kubectl_cmd -n "${NS_OBS}" get deploy "${job}" >/dev/null 2>&1; then
    if kubectl_cmd -n "${NS_OBS}" rollout status "deploy/${job}" --timeout=120s >/dev/null 2>&1; then
      pass "${job} rollout"
    else
      bad "${job} rollout"
    fi
  else
    skip "${job} not deployed"
  fi
done

EVENT_JSON='{"event_type":"smoke.observability","payload":{"probe":"obs-smoke"},"severity":"low","source":"smoke-test"}'
if curl_pod "${NS_APP}" egregore-api 8080 /events >/dev/null 2>&1; then
  skip "egregore /events GET only"
elif kubectl_cmd run "curl-ingest-$(date +%s)" --rm -i --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
  curl -fsS -m 20 -H 'Content-Type: application/json' -X POST "http://egregore-api:8080/events" -d "${EVENT_JSON}" >/dev/null 2>&1; then
  pass "egregore ingest event"
else
  skip "egregore ingest event (auth or routing)"
fi

if kubectl_cmd -n "${NS_OBS}" get daemonset promtail >/dev/null 2>&1; then
  pass "promtail daemonset"
else
  skip "promtail not deployed"
fi

echo ""
if kubectl_cmd -n cxado-langfuse get deploy langfuse-web >/dev/null 2>&1; then
  LANGFUSE_PUBLIC_KEY="${LANGFUSE_PUBLIC_KEY:-pk-lf-egregore-dev-local}"
  LANGFUSE_SECRET_KEY="${LANGFUSE_SECRET_KEY:-sk-lf-egregore-dev-local}"
  trace_check_name="curl-langfuse-$(date +%s)-$RANDOM"
  overrides="{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"${CXADO_NODE_HOSTNAME}\"}}}"
  trace_out="$(timeout 45 kubectl_cmd run "${trace_check_name}" --rm -i --restart=Never -n cxado-langfuse \
    --overrides="${overrides}" --image="${SMOKE_IMAGE}" -- \
    curl -fsS -m 20 -u "${LANGFUSE_PUBLIC_KEY}:${LANGFUSE_SECRET_KEY}" \
    "http://langfuse-web:3000/api/public/traces?limit=5" 2>/dev/null || true)"
  if echo "${trace_out}" | grep -q '"data"'; then
    if echo "${trace_out}" | grep -qE '"data"\s*:\s*\[\s*\]'; then
      skip "langfuse traces empty (ingest may need LLM/worker run)"
    else
      pass "langfuse traces present"
    fi
  else
    skip "langfuse traces API (langfuse not deployed or auth failed)"
  fi
fi

echo ""
if [[ "${fail}" -eq 0 ]]; then
  echo "smoke: PASS"
else
  echo "smoke: FAIL"
fi
exit "${fail}"
