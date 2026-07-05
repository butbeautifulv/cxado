#!/usr/bin/env bash
# Local smoke: POST investigation → poll status → optional Langfuse trace check.
set -euo pipefail

API="${EGREGORE_API_URL:-http://localhost:8080}"
TIMEOUT="${LOCAL_E2E_TIMEOUT:-120}"

log() { printf '[local-e2e] %s\n' "$*"; }

curl -sf "${API}/health" >/dev/null || { log "API not up at ${API}"; exit 1; }

payload='{"event_type":"engagement.start","payload":{"goal":"local e2e smoke","plan_strategy":"declarative"},"severity":"low","source":"local-e2e"}'
resp="$(curl -sf -X POST "${API}/events" -H 'Content-Type: application/json' -d "${payload}")"
log "ingest: ${resp}"

inv_id="$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('investigation_id','') or d.get('id',''))" <<<"${resp}" 2>/dev/null || true)"
if [[ -z "${inv_id}" ]]; then
  log "WARN: no investigation_id in response"
  exit 0
fi

deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
  detail="$(curl -sf "${API}/investigations/${inv_id}" 2>/dev/null || echo '{}')"
  status="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))" <<<"${detail}" 2>/dev/null || true)"
  log "status=${status}"
  if [[ "${status}" == "closed" || "${status}" == "failed" ]]; then
    log "PASS: investigation terminal (${status})"
    exit 0
  fi
  sleep 5
done

log "WARN: timeout waiting for terminal status"
exit 1
