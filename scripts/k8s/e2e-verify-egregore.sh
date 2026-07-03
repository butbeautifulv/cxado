#!/usr/bin/env bash
# Hard-gate E2E verification for Egregore on offline k3s.
#
# Usage:
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/e2e-verify-egregore.sh
#
# Exit 0 only when all gates pass; tee deploy_logs/e2e_verify_*.log
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT:-22}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"
AD_GOAL="${AD_GOAL:-Как защитить Active Directory?}"
POLL_TIMEOUT="${INVESTIGATION_POLL_TIMEOUT:-600}"
OUT_DIR="${E2E_OUT_DIR:-${ROOT}/deploy_logs}"
LOG_FILE="${OUT_DIR}/e2e_verify_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${OUT_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

FAILURES=0

log() { printf '[e2e] %s\n' "$*"; }
fail() { log "FAIL: $*"; FAILURES=$((FAILURES + 1)); }
pass() { log "PASS: $*"; }

kubectl_cmd() {
  local qargs=""
  for arg in "$@"; do
    qargs+=" $(printf '%q' "$arg")"
  done
  if [[ -n "${SSH_HOST}" ]]; then
    # shellcheck disable=SC2086
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "KUBECONFIG=/home/bbv/.kube/config k3s kubectl${qargs}"
  else
    kubectl "$@"
  fi
}

api_exec_get() {
  local path="$1"
  local pod
  pod="$(kubectl_cmd -n "${NS_APP}" get pods -l app=egregore-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | tr -d '\r')"
  [[ -n "${pod}" ]] || return 1
  kubectl_cmd -n "${NS_APP}" exec "${pod}" -- python3 -c "
import urllib.request, sys
r = urllib.request.urlopen('http://127.0.0.1:8080${path}')
sys.stdout.write(r.read().decode())
"
}

api_exec_post() {
  local path="$1"
  local body="$2"
  local pod
  pod="$(kubectl_cmd -n "${NS_APP}" get pods -l app=egregore-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | tr -d '\r')"
  [[ -n "${pod}" ]] || return 1
  kubectl_cmd -n "${NS_APP}" exec "${pod}" -- python3 -c "
import json, urllib.request, sys
body = json.loads(sys.argv[1])
req = urllib.request.Request('http://127.0.0.1:8080${path}', data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'}, method='POST')
try:
    r = urllib.request.urlopen(req)
    print('__HTTP_CODE__:' + str(r.status))
    sys.stdout.write(r.read().decode())
except urllib.error.HTTPError as e:
    print('__HTTP_CODE__:' + str(e.code))
    sys.stdout.write(e.read().decode())
" "$(printf '%s' "${body}")"
}

api_curl() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local name="e2e-$(date +%s)-$RANDOM"
  if [[ -n "${body}" ]]; then
    kubectl_cmd run "${name}" --rm --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
      curl -sS -m 300 -w "\n__HTTP_CODE__:%{http_code}\n__TIME_TOTAL__:%{time_total}\n" \
      -H "Content-Type: application/json" -X "${method}" \
      "http://egregore-api:8080${path}" -d "${body}" 2>/dev/null
  else
    kubectl_cmd run "${name}" --rm --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
      curl -sS -m 300 -w "\n__HTTP_CODE__:%{http_code}\n__TIME_TOTAL__:%{time_total}\n" \
      "http://egregore-api:8080${path}" 2>/dev/null
  fi
}

parse_curl_meta() {
  local raw="$1"
  HTTP_CODE="$(echo "${raw}" | sed -n 's/^__HTTP_CODE__://p' | tail -1)"
  TIME_TOTAL="$(echo "${raw}" | sed -n 's/^__TIME_TOTAL__://p' | tail -1)"
  BODY="$(echo "${raw}" | sed '/^__HTTP_CODE__:/d;/^__TIME_TOTAL__:/d' | sed '/^pod /d;/^All commands/d' | head -c 12000)"
}

log "log file: ${LOG_FILE}"
log "ssh=${SSH_HOST:-local} goal=${AD_GOAL}"

# Gate: health
health_raw="$(api_exec_get "/health" 2>/dev/null || api_curl GET "/health" || true)"
parse_curl_meta "${health_raw}"
if [[ -z "${HTTP_CODE}" ]]; then
  HTTP_CODE="$(echo "${health_raw}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(200 if d.get('status')=='ok' else 0)" 2>/dev/null || echo "")"
  BODY="${health_raw}"
fi
if [[ "${HTTP_CODE}" == "200" ]]; then
  pass "/health 200"
else
  fail "/health expected 200 got ${HTTP_CODE:-none}"
fi

# Gate: POST AD investigation
EVENT_BODY="$(python3 -c "import json; print(json.dumps({'event_type':'manual.investigation','payload':{'goal':'${AD_GOAL}'},'severity':'low','source':'e2e'}))")"
post_raw="$(api_exec_post "/events" "${EVENT_BODY}" || true)"
parse_curl_meta "${post_raw}"
INV_ID="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); e=d.get('event',d); print(e.get('correlation_id') or e.get('id',''))" 2>/dev/null || echo "")"
JOB_IDS="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(d.get('job_ids',[])))" 2>/dev/null || echo "")"

if [[ "${HTTP_CODE}" == "200" ]]; then
  pass "POST manual.investigation http=200"
else
  fail "POST manual.investigation expected 200 got ${HTTP_CODE:-none} body=${BODY:0:200}"
fi

if [[ -n "${JOB_IDS}" ]]; then
  pass "job_ids present (${JOB_IDS})"
else
  fail "job_ids missing in response"
fi

if [[ -z "${INV_ID}" ]]; then
  fail "investigation_id missing"
  log "summary failures=${FAILURES}"
  exit 1
fi

# Poll investigation until closed or job failed
elapsed=0
interval=5
final_status=""
final_body=""
while [[ "${elapsed}" -lt "${POLL_TIMEOUT}" ]]; do
  final_body="$(api_exec_get "/investigations/${INV_ID}?tenant_id=default" 2>/dev/null || true)"
  if [[ -z "${final_body}" ]]; then
    post_raw="$(api_curl GET "/investigations/${INV_ID}?tenant_id=default")"
    parse_curl_meta "${post_raw}"
    final_body="${BODY}"
  fi
  final_status="$(echo "${final_body}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || echo "")"
  if [[ "${final_status}" == "closed" ]]; then
    break
  fi
  jobs_body="$(api_exec_get "/investigations/${INV_ID}/jobs?tenant_id=default" 2>/dev/null || echo '{}')"
  failed="$(echo "${jobs_body}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(any(j.get('status')=='failed' for j in d.get('jobs',[])))" 2>/dev/null || echo False)"
  if [[ "${failed}" == "True" ]]; then
    final_status="failed"
    break
  fi
  sleep "${interval}"
  elapsed=$((elapsed + interval))
done

if [[ "${final_status}" == "closed" ]]; then
  pass "investigation status=closed within ${elapsed}s"
elif [[ "${final_status}" == "failed" ]]; then
  fail "investigation job failed"
else
  fail "investigation poll timeout (${POLL_TIMEOUT}s) last_status=${final_status}"
fi

planner_plan="$(echo "${final_body}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('planner_plan',[]))" 2>/dev/null || echo "")"
planner_rationale="$(echo "${final_body}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('planner_rationale',''))" 2>/dev/null || echo "")"
findings_len="$(echo "${final_body}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('findings_summary',[])))" 2>/dev/null || echo 0)"

if echo "${planner_plan}" | grep -q consultant; then
  pass "planner_plan includes consultant (${planner_plan})"
else
  fail "planner_plan missing consultant: ${planner_plan}"
fi

if echo "${planner_rationale}" | grep -q advisory_fast_path; then
  pass "planner_rationale advisory_fast_path"
else
  log "WARN: planner_rationale=${planner_rationale} (non-fatal if sync planner path)"
fi

if [[ "${findings_len}" -gt 0 ]]; then
  pass "findings_summary len=${findings_len}"
else
  jobs_body="$(api_exec_get "/investigations/${INV_ID}/jobs?tenant_id=default" 2>/dev/null || echo '{}')"
  completed="$(echo "${jobs_body}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(any(j.get('status')=='completed' for j in d.get('jobs',[])))" 2>/dev/null || echo False)"
  if [[ "${completed}" == "True" ]]; then
    pass "job completed (findings empty but job done)"
  else
    fail "findings_summary empty and no completed job"
  fi
fi

# Langfuse ERROR window (best-effort)
if [[ -x "${ROOT}/scripts/k8s/langfuse-benchmark-report.sh" ]]; then
  if CXADO_OFFLINE_SSH_HOST="${SSH_HOST}" CXADO_OFFLINE_SSH_PORT="${SSH_PORT}" \
    "${ROOT}/scripts/k8s/langfuse-benchmark-report.sh" --window-min 30 --grep ERROR >/tmp/e2e_langfuse.txt 2>&1; then
    err_count="$(grep -c ERROR /tmp/e2e_langfuse.txt 2>/dev/null || echo 0)"
    if [[ "${err_count}" -eq 0 ]]; then
      pass "langfuse ERROR count 0"
    else
      fail "langfuse ERROR count=${err_count}"
    fi
  else
    log "WARN: langfuse report skipped or failed"
  fi
fi

# Worker logs: no hung LiteLLM without completion (grep best-effort)
worker_pod="$(kubectl_cmd -n "${NS_APP}" get pods -l app=egregore-worker -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | tr -d '\r' || true)"
if [[ -n "${worker_pod}" ]]; then
  if kubectl_cmd -n "${NS_APP}" logs "${worker_pod}" --tail=200 2>/dev/null | grep -qi "worker job timed out"; then
    log "WARN: worker timeout observed (acceptable if vLLM slow)"
  else
    pass "worker logs: no recent timeout storm"
  fi
fi

log "=== E2E summary failures=${FAILURES} investigation=${INV_ID} ==="
if [[ "${FAILURES}" -gt 0 ]]; then
  exit 1
fi
exit 0
