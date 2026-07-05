#!/usr/bin/env bash
# Validate local Grafana + Prometheus wiring (docker compose profiles).
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3002}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9091}"
EGREGORE_METRICS_URL="${EGREGORE_METRICS_URL:-http://localhost:8080/metrics}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

log() { printf '[validate-local-grafana] %s\n' "$*"; }
fail() { log "FAIL: $*"; exit 1; }

log "Grafana health..."
curl -sf -m 5 "${GRAFANA_URL}/api/health" >/dev/null || fail "Grafana not healthy at ${GRAFANA_URL}"

log "Prometheus health..."
curl -sf -m 5 "${PROMETHEUS_URL}/-/healthy" >/dev/null || fail "Prometheus not healthy at ${PROMETHEUS_URL}"

log "Grafana Prometheus datasource health..."
ds_health="$(curl -sf -m 10 -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  "${GRAFANA_URL}/api/datasources/uid/prometheus/health" 2>/dev/null || true)"
if [[ -z "$ds_health" ]]; then
  fail "could not query Prometheus datasource health (check login / provisioning)"
fi
if ! echo "$ds_health" | grep -q '"status":"OK"'; then
  log "WARN: datasource health response: $ds_health"
  fail "Prometheus datasource not OK in Grafana"
fi

log "Prometheus egregore-api target..."
targets="$(curl -sf -m 10 "${PROMETHEUS_URL}/api/v1/targets")"
if echo "$targets" | grep -q '"job":"egregore-api"'; then
  if echo "$targets" | grep -q '"health":"up".*"job":"egregore-api"' || \
     echo "$targets" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d.get('data',{}).get('activeTargets',[]):
    if t.get('labels',{}).get('job')=='egregore-api':
        print(t.get('health',''))
        sys.exit(0 if t.get('health')=='up' else 1)
sys.exit(2)
" 2>/dev/null; then
    log "egregore-api target UP"
  else
    log "WARN: egregore-api target present but not UP (start: make -C projects/egregore dev-api)"
  fi
else
  log "WARN: egregore-api job not in Prometheus targets"
fi

if curl -sf -m 3 "${EGREGORE_METRICS_URL}" >/dev/null 2>&1; then
  log "egregore metrics endpoint reachable"
else
  log "WARN: ${EGREGORE_METRICS_URL} not reachable (API not running on host)"
fi

log "PASS: local Grafana stack OK"
