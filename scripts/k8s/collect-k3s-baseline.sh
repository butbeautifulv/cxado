#!/usr/bin/env bash
# Collect k3s bottleneck baseline from Prometheus using docs/observability/k3s-bottleneck-promql.yml
#
# Usage:
#   ./scripts/k8s/collect-k3s-baseline.sh
#   PROMETHEUS_URL=https://192.168.0.133:30091 ./scripts/k8s/collect-k3s-baseline.sh
#   BASELINE_CRITICAL_ONLY=1 ./scripts/k8s/collect-k3s-baseline.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

PROMETHEUS_URL="${PROMETHEUS_URL:-https://${CXADO_NODE_IP}:30091}"
QUERY_ENDPOINT="${PROMETHEUS_URL%/}/api/v1/query"
CATALOG="${ROOT}/docs/observability/k3s-bottleneck-promql.yml"
OUT_DIR="${ROOT}/deploy_logs/k3s-baseline"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_FILE="${OUT_DIR}/baseline-${STAMP}.json"

CURL_OPTS=(-fsS)
if [[ "${PROMETHEUS_URL}" == https://* ]]; then
  CURL_OPTS+=(-k)
fi

log() { printf '[collect-k3s-baseline] %s\n' "$*"; }

mkdir -p "${OUT_DIR}"

if [[ ! -f "${CATALOG}" ]]; then
  log "FAIL missing catalog: ${CATALOG}"
  exit 1
fi

export CATALOG BASELINE_CRITICAL_ONLY="${BASELINE_CRITICAL_ONLY:-0}"
mapfile -t QUERY_ROWS < <(
  python3 - <<'PY'
import os
import re
from pathlib import Path

catalog = Path(os.environ["CATALOG"])
critical_only = os.environ.get("BASELINE_CRITICAL_ONLY", "0") == "1"
critical_groups = {"scrape_health", "worker_jobs", "tools", "llm", "k8s"}

current_group = None
group_critical = False
pending_id = None
in_groups = False
pending_expr_lines: list[str] | None = None

for raw in catalog.read_text().splitlines():
    line = raw.split("#", 1)[0].rstrip()
    if not line.strip():
        continue
    if re.match(r"^groups:\s*$", line):
        in_groups = True
        continue
    if not in_groups:
        continue
    if pending_expr_lines is not None:
        if re.match(r"^        [a-z_]+:", line):
            if pending_id and current_group:
                if not (critical_only and current_group not in critical_groups):
                    critical = "1" if group_critical else "0"
                    expr = " ".join(pending_expr_lines).strip()
                    print(f"{pending_id}\t{expr}\t{current_group}\t{critical}")
            pending_expr_lines = None
            pending_id = None
        elif line.startswith("          "):
            pending_expr_lines.append(line.strip())
        continue
    m = re.match(r"^  - id: (\S+)", line)
    if m:
        current_group = m.group(1)
        group_critical = current_group in critical_groups
        continue
    m = re.match(r"^    critical: (true|false)", line)
    if m and current_group:
        group_critical = m.group(1) == "true" or current_group in critical_groups
        continue
    m = re.match(r"^      - id: (\S+)", line)
    if m:
        pending_id = m.group(1)
        continue
    m = re.match(r"^        expr: \|?\s*$", line)
    if m and pending_id and current_group:
        pending_expr_lines = []
        continue
    m = re.match(r'^        expr: (.+)$', line)
    if m and pending_id and current_group:
        if critical_only and current_group not in critical_groups:
            pending_id = None
            continue
        critical = "1" if group_critical else "0"
        expr = m.group(1).strip()
        if (expr.startswith('"') and expr.endswith('"')) or (expr.startswith("'") and expr.endswith("'")):
            expr = expr[1:-1]
        print(f"{pending_id}\t{expr}\t{current_group}\t{critical}")
        pending_id = None

if pending_expr_lines and pending_id and current_group:
    if not (critical_only and current_group not in critical_groups):
        critical = "1" if group_critical else "0"
        expr = " ".join(pending_expr_lines).strip()
        print(f"{pending_id}\t{expr}\t{current_group}\t{critical}")
PY
)

if [[ "${#QUERY_ROWS[@]}" -eq 0 ]]; then
  log "FAIL no queries loaded from ${CATALOG}"
  exit 1
fi

log "Prometheus: ${PROMETHEUS_URL}"
log "Queries: ${#QUERY_ROWS[@]} (critical_only=${BASELINE_CRITICAL_ONLY})"

TMP_RESULTS="$(mktemp)"
: >"${TMP_RESULTS}"
errors=0
critical_fail=0

for row in "${QUERY_ROWS[@]}"; do
  IFS=$'\t' read -r qid expr gid critical <<<"${row}"
  response=""
  if ! response="$(curl "${CURL_OPTS[@]}" -G "${QUERY_ENDPOINT}" --data-urlencode "query=${expr}" 2>&1)"; then
    log "FAIL curl ${qid}"
    errors=$((errors + 1))
    if [[ "${critical}" == "1" ]]; then
      critical_fail=$((critical_fail + 1))
    fi
    QID="${qid}" GID="${gid}" EXPR="${expr}" STATUS="curl_error" DATA='null' \
      python3 - >>"${TMP_RESULTS}" <<'PY'
import json, os
print(json.dumps({
    "id": os.environ["QID"],
    "group": os.environ["GID"],
    "expr": os.environ["EXPR"],
    "status": os.environ["STATUS"],
    "data": None,
}))
PY
    continue
  fi
  status="$(printf '%s' "${response}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))")"
  if [[ "${status}" != "success" ]]; then
    log "FAIL query ${qid}: ${status}"
    errors=$((errors + 1))
    if [[ "${critical}" == "1" ]]; then
      critical_fail=$((critical_fail + 1))
    fi
  fi
  RESP_FILE="$(mktemp)"
  printf '%s' "${response}" >"${RESP_FILE}"
  QID="${qid}" GID="${gid}" EXPR="${expr}" STATUS="${status}" RESP_FILE="${RESP_FILE}" \
    python3 - >>"${TMP_RESULTS}" <<'PY'
import json, os
from pathlib import Path
raw = Path(os.environ["RESP_FILE"]).read_text()
try:
    payload = json.loads(raw)
except json.JSONDecodeError:
    payload = {"status": "json_error", "data": None}
print(json.dumps({
    "id": os.environ["QID"],
    "group": os.environ["GID"],
    "expr": os.environ["EXPR"],
    "status": os.environ["STATUS"] or payload.get("status", "unknown"),
    "data": payload.get("data"),
}))
PY
  rm -f "${RESP_FILE}"
done

python3 - "${OUT_FILE}" "${PROMETHEUS_URL}" "${CXADO_NODE_IP}" "${TMP_RESULTS}" "${errors}" "${critical_fail}" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path

out_file, prom_url, node_ip, tmp, errors, critical_fail = sys.argv[1:7]
results = []
for line in Path(tmp).read_text().splitlines():
    if line.strip():
        results.append(json.loads(line))
doc = {
    "collected_at": datetime.now(timezone.utc).isoformat(),
    "prometheus_url": prom_url,
    "cxado_node_ip": node_ip,
    "query_count": len(results),
    "errors": int(errors),
    "critical_failures": int(critical_fail),
    "results": results,
}
Path(out_file).write_text(json.dumps(doc, indent=2) + "\n")
print(out_file)
PY

rm -f "${TMP_RESULTS}"

log "Wrote ${OUT_FILE}"
log "errors=${errors} critical_failures=${critical_fail}"

if [[ "${critical_fail}" -gt 0 ]]; then
  log "FAIL one or more critical queries failed"
  exit 1
fi

log "OK"
exit 0
