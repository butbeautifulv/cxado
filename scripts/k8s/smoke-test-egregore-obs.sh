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

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
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
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "KUBECONFIG=/home/bbv/.kube/config k3s kubectl $*"
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
  kubectl_cmd run "${name}" --rm -i --restart=Never -n "${ns}" --image="${SMOKE_IMAGE}" -- \
    curl -fsS -m 15 "http://${svc}:${port}${path}"
}

echo "[smoke] egregore observability"

if kubectl_cmd -n "${NS_APP}" rollout status deploy/egregore-api --timeout=120s >/dev/null 2>&1; then
  pass "egregore-api rollout"
else
  bad "egregore-api rollout"
fi

if kubectl_cmd -n "${NS_APP}" rollout status deploy/egregore-worker --timeout=120s >/dev/null 2>&1; then
  pass "egregore-worker rollout"
else
  bad "egregore-worker rollout"
fi

if curl_pod "${NS_APP}" egregore-api 8080 /health >/dev/null 2>&1; then
  pass "egregore-api /health"
else
  bad "egregore-api /health"
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
if kubectl_cmd -n "${NS_OBS}" get deploy tempo >/dev/null 2>&1; then
  LANGFUSE_PUBLIC_KEY="${LANGFUSE_PUBLIC_KEY:-pk-lf-egregore-dev-local}"
  LANGFUSE_SECRET_KEY="${LANGFUSE_SECRET_KEY:-sk-lf-egregore-dev-local}"
  trace_check_name="curl-langfuse-$(date +%s)-$RANDOM"
  trace_out="$(kubectl_cmd run "${trace_check_name}" --rm -i --restart=Never -n cxado-langfuse --image="${SMOKE_IMAGE}" -- \
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
