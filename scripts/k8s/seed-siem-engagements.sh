#!/usr/bin/env bash
# Seed SIEM incident engagements on offline k3s (fire-and-forget).
#
# Usage:
#   ./scripts/k8s/seed-siem-engagements.sh
#   INCIDENTS='INC-894748:uuid:name:cat:sev' ./scripts/k8s/seed-siem-engagements.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS_APP="${CXADO_APP_NS:-cxado-app}"

DEFAULT_INCIDENTS=$'INC-894748:2be38188-d9f5-4d12-8490-8a69637dc603:kata_taa_high_alert:MalwareDetection:High\nINC-894749:6ac53af0-b208-4099-a6eb-9dbd21b7ff00:Computer_Account_Created:DataSecurity:Medium'
INCIDENTS="${INCIDENTS:-$DEFAULT_INCIDENTS}"

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

seed_one() {
  local key="$1" uuid="$2" name="$3" category="$4" severity="$5"
  local pod goal body
  pod="$(api_pod)"
  [[ -n "${pod}" ]] || { echo "no api pod"; return 1; }

  goal="$(date -u +"%d.%m.%Y %H:%M UTC"): SIEM инцидент ${key} (${name}). Категория: ${category}, severity: ${severity}. Разбери инцидент, собери факты из SIEM, не выдумывай PID/cmdline."
  body="$(GOAL="${goal}" KEY="${key}" UUID="${uuid}" python3 -c '
import json, os
print(json.dumps({
    "profile_id": "cybersec-soc",
    "goal": os.environ["GOAL"],
    "plan_strategy": "meta_llm",
    "mode": "async",
    "input": {
        "incident_id": os.environ["UUID"],
        "incident_key": os.environ["KEY"],
        "source": "seed-test",
    },
}, ensure_ascii=False))
')"

  echo "=== ${key} (${uuid}) ==="
  kubectl_cmd -n "${NS_APP}" exec "${pod}" -- python3 -c "
import json, urllib.request, sys
body = json.loads(sys.argv[1])
req = urllib.request.Request(
    'http://127.0.0.1:8080/v1/engagements',
    data=json.dumps(body).encode(),
    headers={'Content-Type': 'application/json'},
    method='POST',
)
try:
    r = urllib.request.urlopen(req)
    print('HTTP', r.status)
    sys.stdout.write(r.read().decode())
except urllib.error.HTTPError as e:
    print('HTTP', e.code)
    sys.stdout.write(e.read().decode())
    raise SystemExit(1)
" "${body}"
}

while IFS= read -r line || [[ -n "${line}" ]]; do
  [[ -z "${line}" ]] && continue
  IFS=':' read -r key uuid name category severity <<<"${line}"
  seed_one "${key}" "${uuid}" "${name}" "${category}" "${severity}"
done <<<"${INCIDENTS}"
