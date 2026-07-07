#!/usr/bin/env bash
# Veil graph layer only (Neo4j + API + MCP) on cxado-net — no ingest/NATS pipeline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE_DIR="$ROOT/deploy/compose"
NETWORK="${CXADO_NETWORK:-cxado-net}"
VEIL_COMPOSE="$COMPOSE_DIR/veil-graph-lite.yml"

log() { printf '[cxado-up-veil] %s\n' "$*"; }

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  log "creating network $NETWORK"
  docker network create "$NETWORK" >/dev/null
fi

if curl -sf -m 3 "http://localhost:8090/health" >/dev/null 2>&1; then
  log "veil-api already healthy on :8090"
else
  log "starting veil graph (neo4j + api + mcp)..."
  docker compose -f "$VEIL_COMPOSE" --profile mcp up -d --build
fi

wait_http() {
  local name="$1" url="$2" tries="${3:-90}"
  local i=0
  until curl -sf -m 3 "$url" >/dev/null 2>&1; do
    i=$((i + 1))
    if [[ $i -ge $tries ]]; then
      log "WARN: $name not healthy at $url after ${tries} attempts"
      return 1
    fi
    sleep 2
  done
  log "$name ok ($url)"
}

wait_http "veil-api" "http://localhost:8090/health" 120 || true
wait_http "veil-mcp" "http://localhost:8091/health" 120 || true

echo ""
echo "veil graph is up (graph-only, MCP enabled)."
echo "  veil-api:  http://localhost:8090/health"
echo "  veil-mcp:  http://localhost:8091/health"
echo ""
echo "In projects/egregore/.env:"
echo "  VEIL_MCP_URL=http://localhost:8091/mcp"
echo "  VEIL_MCP_ENABLED=true"
echo ""
echo "Smoke: make cxado-smoke-veil-mcp"
