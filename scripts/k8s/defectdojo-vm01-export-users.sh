#!/usr/bin/env bash
# Export DefectDojo users from VM_01 (reference before decommission).
#
# Usage:
#   ./scripts/k8s/defectdojo-vm01-export-users.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

OUT="${ROOT}/deploy/.secrets/defectdojo-vm01-users.json"
DD_URL="${DEFECTDOJO_VM01_URL:-http://10.20.16.195:8080}"
TOKEN="${DEFECTDOJO_VM01_API_TOKEN:-${DEFECTDOJO_API_TOKEN:-${VM_01_DEFECTDOJO_API_TOKEN:-}}}"
SSH_JUMP="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
VM_HOST="${VM_01_IP:-10.20.16.195}"

log() { printf '[defectdojo-vm01-export] %s\n' "$*"; }

if [[ -z "${TOKEN}" ]]; then
  log "fetch token from VM_01"
  TOKEN="$(ssh -o ProxyJump="${SSH_JUMP}" "astradmin@${VM_HOST}" \
    "curl -sk -X POST '${DD_URL%/}/api/v2/api-token-auth/' \
      -H 'Content-Type: application/json' \
      -d '{\"username\":\"${VM_01_DEFECTDOJO_SU_NAME:-admin}\",\"password\":\"${VM_01_DEFECTDOJO_SU_PWD}\"}'" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))' 2>/dev/null || true)"
fi

[[ -n "${TOKEN}" ]] || { echo "missing API token for VM_01" >&2; exit 2; }

log "GET users -> ${OUT}"
curl -sk -H "Authorization: Token ${TOKEN}" \
  "${DD_URL%/}/api/v2/users/?limit=200" -o "${OUT}"
log "ok ($(python3 -c "import json; print(len(json.load(open('${OUT}')).get('results',[])))" 2>/dev/null || echo '?') users)"
