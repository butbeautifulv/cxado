#!/usr/bin/env bash
# Health summary for cxado-default stack.
set -euo pipefail

check() {
  local name="$1" url="$2"
  if curl -sf -m 3 "$url" >/dev/null 2>&1; then
    printf '  %-18s OK  %s\n' "$name" "$url"
  else
    printf '  %-18s FAIL %s\n' "$name" "$url"
  fi
}

echo "cxado status"
PROFILE="${CXADO_PROFILE:-default}"
check "veil-api" "http://localhost:8090/health"
check "veil-mcp" "http://localhost:8091/health"
check "egregore-api" "http://localhost:8080/health"
check "grafana" "http://localhost:3002/api/health"
check "prometheus" "http://localhost:9091/-/healthy"
if [[ "$PROFILE" != "lite" ]]; then
  check "tempo" "http://localhost:3200/ready"
fi

if curl -sf -m 3 "http://localhost:9091/api/v1/targets" 2>/dev/null | grep -q '"health":"up"'; then
  echo ""
  echo "Prometheus targets (up):"
  curl -sf "http://localhost:9091/api/v1/targets" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d.get('data',{}).get('activeTargets',[]):
    job=t.get('labels',{}).get('job','?')
    health=t.get('health','?')
    print(f'    {job}: {health}')
" 2>/dev/null || true
fi
