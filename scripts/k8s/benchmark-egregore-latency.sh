#!/usr/bin/env bash
# Egregore latency benchmark matrix B1–B5 (offline k3s).
#
# Usage:
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/benchmark-egregore-latency.sh
#
# Env:
#   API_BASE — default http://egregore-api.cxado-app.svc.cluster.local:8080 (in-cluster)
#   For remote: runs curl via kubectl run in cxado-app
#   AD_GOAL — default "Как защитить Active Directory?"
#   RUNS — repetitions per benchmark (default: 1 for quick, 3 for median)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT:-22}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"
AD_GOAL="${AD_GOAL:-Как защитить Active Directory?}"
RUNS="${BENCHMARK_RUNS:-1}"
POLL_TIMEOUT="${INVESTIGATION_POLL_TIMEOUT:-600}"
VLLM_URL="${VLLM_URL:-http://10.8.185.185:11611/v1/chat/completions}"
VLLM_MODEL="${VLLM_MODEL:-Kbenkhaled/Qwen3.5-27B-NVFP4}"
OUT_DIR="${BENCHMARK_OUT_DIR:-${ROOT}/deploy_logs}"
OUT_JSON="${OUT_DIR}/benchmark_$(date +%Y%m%d_%H%M%S).json"

mkdir -p "${OUT_DIR}"

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
  if [[ -z "${pod}" ]]; then
    return 1
  fi
  kubectl_cmd -n "${NS_APP}" exec "${pod}" -- python3 -c "
import urllib.request, sys
r = urllib.request.urlopen('http://127.0.0.1:8080${path}')
sys.stdout.write(r.read().decode())
" 2>/dev/null
}

api_curl() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local name="bench-$(date +%s)-$RANDOM"
  if [[ -n "${body}" ]]; then
    kubectl_cmd run "${name}" --rm -i --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
      curl -sS -m 300 -w "\n__HTTP_CODE__:%{http_code}\n__TIME_TOTAL__:%{time_total}\n" \
      -H "Content-Type: application/json" -X "${method}" \
      "http://egregore-api:8080${path}" -d "${body}" 2>/dev/null
  else
    kubectl_cmd run "${name}" --rm -i --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
      curl -sS -m 300 -w "\n__HTTP_CODE__:%{http_code}\n__TIME_TOTAL__:%{time_total}\n" \
      "http://egregore-api:8080${path}" 2>/dev/null
  fi
}

vllm_bench() {
  local max_tokens="$1"
  local name="vllm-bench-$(date +%s)-$RANDOM"
  kubectl_cmd run "${name}" --rm -i --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
    curl -sS -m 300 -w "\n__TIME_TOTAL__:%{time_total}\n" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${VLLM_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Brief SOC plan for AD hardening. JSON reply field only.\"}],\"max_tokens\":${max_tokens},\"temperature\":0.1}" \
    "${VLLM_URL}" 2>/dev/null
}

parse_curl_meta() {
  local raw="$1"
  HTTP_CODE="$(echo "${raw}" | sed -n 's/^__HTTP_CODE__://p' | tail -1)"
  TIME_TOTAL="$(echo "${raw}" | sed -n 's/^__TIME_TOTAL__://p' | tail -1)"
  BODY="$(echo "${raw}" | sed '/^__HTTP_CODE__:/d;/^__TIME_TOTAL__:/d' | sed '/^pod /d;/^All commands/d' | head -c 8000)"
}

poll_investigation() {
  local inv_id="$1"
  local start_ts="$2"
  local elapsed=0
  local interval=5
  while [[ "${elapsed}" -lt "${POLL_TIMEOUT}" ]]; do
    local detail
    detail="$(api_exec_get "/investigations/${inv_id}?tenant_id=default" || true)"
    if [[ -z "${detail}" ]]; then
      detail="$(api_curl GET "/investigations/${inv_id}?tenant_id=default")"
      parse_curl_meta "${detail}"
    else
      HTTP_CODE="200"
      BODY="${detail}"
    fi
    local status planner personas
    status="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || echo "")"
    planner="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('planner_status',''))" 2>/dev/null || echo "")"
    personas="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('planner_plan',[]))" 2>/dev/null || echo "")"
    if [[ "${status}" == "closed" || "${status}" == "failed" ]]; then
      echo "DONE status=${status} planner=${planner} personas=${personas} wall_s=$((elapsed + $(date +%s) - start_ts))"
      return 0
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
  echo "TIMEOUT after ${POLL_TIMEOUT}s"
  return 1
}

log() { printf '[benchmark] %s\n' "$*"; }

RESULTS=()

run_bench() {
  local id="$1"
  local desc="$2"
  local method="$3"
  local path="$4"
  local body="$5"
  log "${id}: ${desc}"
  local raw
  raw="$(api_curl "${method}" "${path}" "${body}")"
  parse_curl_meta "${raw}"
  log "  http=${HTTP_CODE} time=${TIME_TOTAL}s"
  RESULTS+=("{\"id\":\"${id}\",\"http_code\":${HTTP_CODE:-0},\"time_s\":${TIME_TOTAL:-0},\"body_preview\":$(echo "${BODY}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()[:500]))' 2>/dev/null || echo '""')}")
}

log "=== Egregore latency benchmark ==="
log "goal: ${AD_GOAL}"
log "runs: ${RUNS}"
log ""

# B1 consultation
EVENT_B1='{"event_type":"manual.consultation","payload":{"goal":"'"${AD_GOAL}"'"},"severity":"low","source":"benchmark"}'
run_bench B1 "manual.consultation + AD goal" POST "/events" "${EVENT_B1}"

# B2 investigation
EVENT_B2='{"event_type":"manual.investigation","payload":{"goal":"'"${AD_GOAL}"'"},"severity":"low","source":"benchmark"}'
log "B2: manual.investigation + AD goal (with poll)"
B2_START=$(date +%s)
raw="$(api_curl POST "/events" "${EVENT_B2}")"
parse_curl_meta "${raw}"
log "  http=${HTTP_CODE} accept_time=${TIME_TOTAL}s"
INV_ID="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); e=d.get('event',{}); print(e.get('correlation_id') or e.get('id',''))" 2>/dev/null || echo "")"
if [[ -n "${INV_ID}" && ( "${HTTP_CODE}" == "202" || "${HTTP_CODE}" == "200" ) ]]; then
  poll_investigation "${INV_ID}" "${B2_START}" | tee -a "${OUT_DIR}/benchmark_b2_poll.log" || true
fi
RESULTS+=("{\"id\":\"B2\",\"http_code\":${HTTP_CODE:-0},\"time_s\":${TIME_TOTAL:-0},\"investigation_id\":\"${INV_ID}\"}")

# B3 sessions plan
SESSION_B3='{"goal":"'"${AD_GOAL}"'","mode":"plan","message":"'"${AD_GOAL}"'"}'
run_bench B3 "POST /sessions plan mode" POST "/sessions" "${SESSION_B3}"

# B4 sessions ask
SESSION_B4='{"goal":"'"${AD_GOAL}"'","mode":"ask","message":"'"${AD_GOAL}"'"}'
run_bench B4 "POST /sessions ask mode" POST "/sessions" "${SESSION_B4}"

# B5 vLLM direct
log "B5: vLLM direct 512 tokens"
raw="$(vllm_bench 512)"
TIME_TOTAL="$(echo "${raw}" | sed -n 's/^__TIME_TOTAL__://p' | tail -1)"
log "  vllm_512_time=${TIME_TOTAL}s"
RESULTS+=("{\"id\":\"B5_512\",\"time_s\":${TIME_TOTAL:-0}}")
log "B5: vLLM direct 1024 tokens"
raw="$(vllm_bench 1024)"
TIME_TOTAL="$(echo "${raw}" | sed -n 's/^__TIME_TOTAL__://p' | tail -1)"
log "  vllm_1024_time=${TIME_TOTAL}s"
RESULTS+=("{\"id\":\"B5_1024\",\"time_s\":${TIME_TOTAL:-0}}")

printf '{"date":"%s","goal":%s,"results":[%s]}\n' \
  "$(date -Is)" \
  "$(python3 -c "import json; print(json.dumps('${AD_GOAL}'))")" \
  "$(IFS=,; echo "${RESULTS[*]}")" > "${OUT_JSON}"

log ""
log "JSON report: ${OUT_JSON}"
log "Run langfuse report: ./scripts/k8s/langfuse-benchmark-report.sh"
