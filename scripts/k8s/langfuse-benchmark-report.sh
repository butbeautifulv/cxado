#!/usr/bin/env bash
# Langfuse forensic + latency report for egregore offline.
#
# Usage:
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/langfuse-benchmark-report.sh
#   SEARCH="Active Directory" ./scripts/k8s/langfuse-benchmark-report.sh
#
# Env:
#   LANGFUSE_PUBLIC_KEY / LANGFUSE_SECRET_KEY (default: pk-lf-egregore-dev-local)
#   LANGFUSE_BASE_URL — direct HTTP (e.g. http://localhost:3001) skips kubectl pod curl
#   SEARCH — substring filter on trace input/output (default: Active Directory)
#   TRACE_LIMIT — max traces to fetch (default: 50)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT:-22}"
NS_LF="${CXADO_LANGFUSE_NS:-cxado-langfuse}"
SMOKE_IMAGE="${CXADO_SMOKE_IMAGE:-curlimages/curl:8.5.0}"
LANGFUSE_BASE_URL="${LANGFUSE_BASE_URL:-}"

LANGFUSE_PUBLIC_KEY="${LANGFUSE_PUBLIC_KEY:-pk-lf-egregore-dev-local}"
LANGFUSE_SECRET_KEY="${LANGFUSE_SECRET_KEY:-sk-lf-egregore-dev-local}"
SEARCH="${SEARCH:-Active Directory}"
TRACE_LIMIT="${TRACE_LIMIT:-50}"
OUT_DIR="${BENCHMARK_OUT_DIR:-${ROOT}/deploy_logs}"
OUT_FILE="${OUT_DIR}/langfuse_forensic_$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "${OUT_DIR}"

kubectl_cmd() {
  if [[ -n "${SSH_HOST}" ]]; then
    ssh -p "${SSH_PORT}" "${SSH_HOST}" "KUBECONFIG=/home/bbv/.kube/config k3s kubectl $*"
  else
    kubectl "$@"
  fi
}

lf_curl() {
  local path="$1"
  if [[ -n "${LANGFUSE_BASE_URL}" ]]; then
    curl -fsS -m 120 -u "${LANGFUSE_PUBLIC_KEY}:${LANGFUSE_SECRET_KEY}" \
      "${LANGFUSE_BASE_URL%/}${path}"
    return
  fi
  local name="lf-report-$(date +%s)-$RANDOM"
  kubectl_cmd run "${name}" --rm -i --restart=Never -n "${NS_LF}" --image="${SMOKE_IMAGE}" -- \
    curl -fsS -m 120 -u "${LANGFUSE_PUBLIC_KEY}:${LANGFUSE_SECRET_KEY}" \
    "http://langfuse-web:3000${path}" 2>/dev/null
}

strip_kubectl_trailer() {
  python3 -c "
import sys
raw = sys.stdin.read()
for marker in ('pod \"', 'All commands'):
    i = raw.find(marker)
    if i > 0:
        raw = raw[:i].strip()
        break
sys.stdout.write(raw)
"
}

log() { printf '%s\n' "$*" | tee -a "${OUT_FILE}"; }

log "# Langfuse forensic report"
log "- date: $(date -Is)"
log "- search: ${SEARCH}"
log ""

log "## ERROR observations (recent)"
ERR_JSON="$(lf_curl "/api/public/observations?limit=100&level=ERROR" | strip_kubectl_trailer || true)"
if [[ -z "${ERR_JSON}" || "${ERR_JSON}" != "{"* ]]; then
  log "(no data or auth failed — set LANGFUSE_BASE_URL or check keys)"
else
  printf '%s' "${ERR_JSON}" | python3 -c "
import json, sys
from collections import Counter
raw = sys.stdin.read().strip()
if not raw:
    print('(no data)')
    sys.exit(0)
d = json.loads(raw)
obs = d.get('data', [])
print(f'total ERROR observations: {len(obs)}')
by_msg = Counter((o.get('statusMessage') or '')[:80] for o in obs)
for msg, c in by_msg.most_common(10):
    if msg:
        print(f'  {c}x {msg}')
print()
for o in obs[:15]:
    print(f\"trace={o.get('traceId','')[:16]} name={o.get('name')} start={o.get('startTime')}\")
    sm = o.get('statusMessage') or ''
    if sm:
        print(f'  status: {sm[:120]}')
" | tee -a "${OUT_FILE}"
fi

log ""
log "## Egregore traces (name filter)"
TR_JSON="$(lf_curl "/api/public/traces?limit=${TRACE_LIMIT}" | strip_kubectl_trailer)"
printf '%s' "${TR_JSON}" | python3 -c "
import json, sys
search = '''${SEARCH}'''.lower()
raw = sys.stdin.read().strip()
if not raw:
    print('(no data)')
    sys.exit(0)
d = json.loads(raw)
traces = d.get('data', [])
print(f'total traces fetched: {len(traces)}')
eg = [t for t in traces if 'egregore' in (t.get('name') or '').lower() or 'evaluator' in (t.get('name') or '').lower()]
print(f'egregore/evaluator traces: {len(eg)}')
print()
print('trace_id | timestamp | name | match')
for t in eg[:30]:
    blob = json.dumps(t.get('input', '')) + json.dumps(t.get('output', ''))
    match = search in blob.lower() if search else False
    mark = 'AD' if match else '  '
    print(f\"{mark} {t.get('id','')[:20]} | {t.get('timestamp','')[:19]} | {(t.get('name') or '')[:40]}\")
" | tee -a "${OUT_FILE}"

if [[ -n "${SEARCH}" ]]; then
  log ""
  log "## Traces matching SEARCH='${SEARCH}'"
  printf '%s' "${TR_JSON}" | SEARCH="${SEARCH}" python3 -c "
import json, os, sys
search = os.environ.get('SEARCH', '').lower()
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
d = json.loads(raw)
for t in d.get('data', []):
    blob = json.dumps(t, ensure_ascii=False).lower()
    if search and search not in blob:
        continue
    print(f\"id={t.get('id')} name={t.get('name')} ts={t.get('timestamp')}\")
" | tee -a "${OUT_FILE}" || log "(no matches)"
fi

log ""
log "## Observation latency sample (recent DEFAULT, egregore)"
OBS_JSON="$(lf_curl "/api/public/observations?limit=30" | strip_kubectl_trailer)"
printf '%s' "${OBS_JSON}" | python3 -c "
import json, sys
from datetime import datetime
raw = sys.stdin.read().strip()
if not raw:
    print('(no data)')
    sys.exit(0)
d = json.loads(raw)
for o in d.get('data', []):
    if 'egregore' not in (o.get('name') or '').lower() and o.get('name') not in ('conductor', 'model', 'LiteLLMChatModel', 'planner'):
        continue
    if o.get('level') == 'ERROR':
        continue
    start = o.get('startTime', '')
    end = o.get('endTime', '')
    lat = ''
    if start and end:
        try:
            s = datetime.fromisoformat(start.replace('Z', '+00:00'))
            e = datetime.fromisoformat(end.replace('Z', '+00:00'))
            lat = f'{(e-s).total_seconds():.2f}s'
        except Exception:
            lat = '?'
    usage = o.get('usage') or {}
    print(f\"{start[:19]} | {lat:>8} | {o.get('name','')[:25]} | trace={str(o.get('traceId',''))[:12]}\")
" | tee -a "${OUT_FILE}"

log ""
log "## TOOL / SPAN observations (recent)"
TOOL_JSON="$(lf_curl "/api/public/observations?limit=100" | strip_kubectl_trailer)"
printf '%s' "${TOOL_JSON}" | python3 -c "
import json, sys
from collections import Counter
raw = sys.stdin.read().strip()
if not raw:
    print('(no data)')
    sys.exit(0)
d = json.loads(raw)
obs = d.get('data', [])
types = Counter(o.get('type') or '?' for o in obs)
print('observation types:', dict(types.most_common()))
tool_like = [o for o in obs if (o.get('type') or '').upper() in ('TOOL', 'SPAN') or 'tool' in (o.get('name') or '').lower()]
print(f'TOOL/SPAN/tool-name count: {len(tool_like)}')
for o in tool_like[:20]:
    print(f\"  {o.get('type')} | {o.get('name')} | trace={str(o.get('traceId',''))[:16]}\")
" | tee -a "${OUT_FILE}"

log ""
log "## Veil / MCP mentions in recent traces"
printf '%s' "${TR_JSON}" | python3 -c "
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    sys.exit(0)
d = json.loads(raw)
for t in d.get('data', []):
    blob = json.dumps(t, ensure_ascii=False).lower()
    if 'veil' in blob or 'mcp' in blob:
        print(f\"veil/mcp hint: id={t.get('id')} name={t.get('name')}\")
" | tee -a "${OUT_FILE}" || log "(no veil/mcp in recent traces)"

log ""
log "Report saved: ${OUT_FILE}"
