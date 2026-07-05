#!/usr/bin/env bash
# Validate PromQL expressions from Grafana dashboard JSON against Prometheus.
#
# Usage:
#   ./scripts/k8s/validate-grafana-promql.sh
#   GRAFANA_VALIDATE_OFFLINE=1 ./scripts/k8s/validate-grafana-promql.sh  # skip Prometheus (no k3s)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

PROMETHEUS_URL="${PROMETHEUS_URL:-https://${CXADO_NODE_IP}:30091}"
QUERY_ENDPOINT="${PROMETHEUS_URL%/}/api/v1/query"
CURL_OPTS=(-fsS)
if [[ "${PROMETHEUS_URL}" == https://* ]]; then
  CURL_OPTS+=(-k)
fi
DASHBOARDS="${ROOT}/deploy/observability/grafana/dashboards"
export DASHBOARDS

log() { printf '[validate-promql] %s\n' "$*"; }

substitute_vars() {
  local expr="$1"
  expr="${expr//\$__rate_interval/5m}"
  expr="${expr//\$__interval/5m}"
  expr="${expr//\$persona/.+}"
  expr="${expr//\$service/.+}"
  expr="${expr//\$namespace/.+}"
  expr="${expr//\$instance/.+}"
  expr="${expr//\$model_name/.+}"
  expr="${expr//\$job/.+}"
  expr="${expr//\$trace_id/.+}"
  expr="${expr//\$correlation_id/.+}"
  printf '%s' "$expr"
}

errors=0
checked=0
offline="${GRAFANA_VALIDATE_OFFLINE:-0}"

while IFS= read -r expr; do
  [[ -z "${expr}" ]] && continue
  prepared="$(substitute_vars "${expr}")"
  checked=$((checked + 1))
  if [[ "${offline}" == "1" ]]; then
    continue
  fi
  response="$(curl "${CURL_OPTS[@]}" -G "${QUERY_ENDPOINT}" --data-urlencode "query=${prepared}" 2>&1)" || {
    log "FAIL curl: ${prepared}"
    errors=$((errors + 1))
    continue
  }
  status="$(printf '%s' "${response}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))")"
  if [[ "${status}" != "success" ]]; then
    err="$(printf '%s' "${response}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error', d))")"
    log "FAIL parse: ${prepared}"
    log "      ${err}"
    errors=$((errors + 1))
  fi
done < <(
  python3 - <<'PY'
import json
from pathlib import Path

root = Path(__import__("os").environ["DASHBOARDS"])
for path in sorted(root.rglob("*.json")):
    data = json.loads(path.read_text())
    for panel in data.get("panels", []):
        for target in panel.get("targets", []):
            expr = target.get("expr")
            if not expr:
                continue
            ds = target.get("datasource") or {}
            if isinstance(ds, dict) and ds.get("type") not in (None, "prometheus"):
                continue
            if isinstance(ds, str) and ds not in ("prometheus", "${datasource}"):
                continue
            print(expr)
PY
)

log "checked ${checked} prometheus expressions"
if [[ "${offline}" == "1" ]]; then
  log "offline mode — skipped live Prometheus queries (set GRAFANA_VALIDATE_OFFLINE=0 to validate against k3s)"
  exit 0
fi
if [[ "${errors}" -gt 0 ]]; then
  log "${errors} error(s)"
  exit 1
fi
log "all queries OK"
