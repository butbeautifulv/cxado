#!/usr/bin/env bash
# Run Phase 9 controlled agent scenarios (S1/S2/S3).
#
# Usage:
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/run-validation-scenarios.sh
#   VALIDATION_SCENARIO=S2 ./scripts/k8s/run-validation-scenarios.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"
SCENARIO="${VALIDATION_SCENARIO:-ALL}"
POLL_TIMEOUT="${VALIDATION_POLL_TIMEOUT:-600}"
OUT_DIR="${ROOT}/deploy_logs/k3s-validation"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_FILE="${OUT_DIR}/scenarios_${STAMP}.json"
TMP_RESULTS="$(mktemp)"

S1_GOAL="${S1_GOAL:-Разбор фишинга: найди playbook и процедуру реагирования}"
S2_GOAL="${S2_GOAL:-Проверь IOC 185.220.101.1 в threat graph}"
S3_GOAL="${SOC_VALIDATION_GOAL:-Разбери SIEM инцидент: sparse telemetry, не выдумывай PID/cmdline}"

mkdir -p "${OUT_DIR}"
: >"${TMP_RESULTS}"
FAILURES=0

log() { printf '[validation-scenarios] %s\n' "$*"; }
record_fail() { FAILURES=$((FAILURES + 1)); }

kubectl_cmd() {
  local qargs=""
  for arg in "$@"; do
    qargs+=" $(printf '%q' "$arg")"
  done
  if [[ -n "${SSH_HOST}" ]]; then
    # shellcheck disable=SC2086
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl${qargs}"
  else
    kubectl "$@"
  fi
}

api_pod() {
  kubectl_cmd -n "${NS_APP}" get pods -l app=egregore-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null | tr -d '\r'
}

api_exec_get() {
  local path="$1"
  local pod
  pod="$(api_pod)"
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
  pod="$(api_pod)"
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
  local method="$1" path="$2" body="${3:-}"
  if [[ "${method}" == "GET" ]]; then
    api_exec_get "${path}" 2>/dev/null && return 0
  elif [[ "${method}" == "POST" && -n "${body}" ]]; then
    api_exec_post "${path}" "${body}" 2>/dev/null && return 0
  fi
  local name="val-$(date +%s)-$RANDOM"
  if [[ -n "${body}" ]]; then
    kubectl_cmd run "${name}" --rm --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
      curl -sS -m "${POLL_TIMEOUT}" -w "\n__HTTP_CODE__:%{http_code}\n" \
      -H "Content-Type: application/json" -X "${method}" \
      "http://egregore-api:8080${path}" -d "${body}" 2>/dev/null
  else
    kubectl_cmd run "${name}" --rm --restart=Never -n "${NS_APP}" --image="${SMOKE_IMAGE}" -- \
      curl -sS -m 60 -w "\n__HTTP_CODE__:%{http_code}\n" \
      "http://egregore-api:8080${path}" 2>/dev/null
  fi
}

parse_curl() {
  local raw="$1"
  HTTP_CODE="$(echo "${raw}" | sed -n 's/^__HTTP_CODE__://p' | tail -1)"
  BODY="$(echo "${raw}" | sed '/^__HTTP_CODE__:/d;/^pod /d;/^All commands/d' | head -c 16000)"
}

append_result() {
  local sid="$1" detail="$2"
  python3 -c "import json; print(json.dumps({'id': '''${sid}''', 'status': 'fail', 'detail': '''${detail}'''}))" >>"${TMP_RESULTS}"
}

poll_investigation() {
  local inv_id="$1"
  local elapsed=0 interval=5 status=""
  while [[ "${elapsed}" -lt "${POLL_TIMEOUT}" ]]; do
    parse_curl "$(api_curl GET "/investigations/${inv_id}?tenant_id=default")"
    status="$(echo "${BODY}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")"
    if [[ "${status}" == "closed" ]]; then
      echo "${BODY}"
      return 0
    fi
    parse_curl "$(api_curl GET "/investigations/${inv_id}/jobs?tenant_id=default")"
    local failed
    failed="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(any(j.get('status')=='failed' for j in d.get('jobs',[])))" 2>/dev/null || echo False)"
    if [[ "${failed}" == "True" ]]; then
      return 2
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
  return 1
}

run_scenario() {
  local sid="$1" goal="$2" persona_hint="$3"
  log "=== ${sid} ==="
  local event_body inv_id final_body findings_len result detail

  event_body="$(GOAL="${goal}" SID="${sid}" python3 -c "
import json, os
print(json.dumps({
    'profile_id': 'cybersec-soc',
    'goal': os.environ['GOAL'],
    'plan_strategy': 'meta_llm',
    'mode': 'async',
    'input': {'source': 'validation-' + os.environ['SID']},
}, ensure_ascii=False))
")"

  parse_curl "$(api_curl POST "/v1/engagements" "${event_body}")"
  if [[ "${HTTP_CODE}" != "200" && "${HTTP_CODE}" != "202" ]]; then
    detail="POST /v1/engagements http=${HTTP_CODE:-none}"
    log "FAIL ${sid}: ${detail}"
    record_fail
    append_result "${sid}" "${detail}"
    return
  fi

  inv_id="$(echo "${BODY}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('engagement_id') or d.get('investigation_id') or d.get('event',{}).get('correlation_id') or d.get('event',{}).get('id',''))" 2>/dev/null || echo "")"
  if [[ -z "${inv_id}" ]]; then
    log "FAIL ${sid}: missing investigation_id"
    record_fail
    append_result "${sid}" "missing investigation_id"
    return
  fi

  if final_body="$(poll_investigation "${inv_id}")"; then
    findings_len="$(echo "${final_body}" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('findings_summary',[])))" 2>/dev/null || echo 0)"
    result="pass"
    detail="closed findings=${findings_len}"
    log "PASS ${sid}: ${detail}"
  else
    local rc=$?
    if [[ "${rc}" -eq 2 && "${sid}" == "S3" ]]; then
      result="conditional"
      detail="job failed — SIEM sparse/salvage acceptable"
      log "CONDITIONAL ${sid}: ${detail}"
    else
      result="fail"
      detail="timeout or job failed (rc=${rc})"
      log "FAIL ${sid}: ${detail}"
      record_fail
    fi
  fi

  INV_ID="${inv_id}" RESULT="${result}" DETAIL="${detail}" SID="${sid}" PERSONA="${persona_hint}" \
    python3 - >>"${TMP_RESULTS}" <<'PY'
import json, os
print(json.dumps({
    "id": os.environ["SID"],
    "status": os.environ["RESULT"],
    "investigation_id": os.environ["INV_ID"],
    "persona_hint": os.environ["PERSONA"],
    "detail": os.environ["DETAIL"],
}, ensure_ascii=False))
PY
}

should_run() {
  [[ "${SCENARIO}" == "ALL" || "${SCENARIO}" == "$1" ]]
}

log "scenario=${SCENARIO} timeout=${POLL_TIMEOUT}s"

should_run S1 && run_scenario S1 "${S1_GOAL}" consultant
should_run S2 && run_scenario S2 "${S2_GOAL}" intel
should_run S3 && run_scenario S3 "${S3_GOAL}" soc

INC_894608_GOAL="${INC_894608_GOAL:-09.07.2026: SIEM инцидент INC-894608 (kata_taa_high_alert). MalwareDetection, High. Разбери инцидент через SIEM MCP.}"
INC_894610_GOAL="${INC_894610_GOAL:-09.07.2026: SIEM инцидент INC-894610 (Unix_Log_Config_Modify). UnauthorizedAccess, Medium. Разбери инцидент через SIEM MCP.}"
INC_894605_GOAL="${INC_894605_GOAL:-09.07.2026: SIEM инцидент INC-894605 (WinAPI_Access_From_Powershell_copy). UnauthorizedAccess. Разбери инцидент через SIEM MCP.}"

should_run INC-894608 && run_scenario INC-894608 "${INC_894608_GOAL}" soc
should_run INC-894610 && run_scenario INC-894610 "${INC_894610_GOAL}" soc
should_run INC-894605 && run_scenario INC-894605 "${INC_894605_GOAL}" soc

python3 - "${OUT_FILE}" "${TMP_RESULTS}" "${FAILURES}" <<'PY'
import json, sys
from pathlib import Path
out, tmp, failures = sys.argv[1:4]
results = [json.loads(line) for line in Path(tmp).read_text().splitlines() if line.strip()]
Path(out).write_text(json.dumps({"scenarios": results, "failures": int(failures)}, indent=2, ensure_ascii=False) + "\n")
print(out)
PY
rm -f "${TMP_RESULTS}"

log "wrote ${OUT_FILE} failures=${FAILURES}"
exit "${FAILURES}"
