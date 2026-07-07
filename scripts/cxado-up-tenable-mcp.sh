#!/usr/bin/env bash
# Start tenable-mcp HTTP server on :8095 (host process, not Docker).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TENABLE_DIR="$ROOT/projects/tenable-mcp"
PORT="${TENABLE_MCP_PORT:-8095}"
PID_FILE="${TMPDIR:-/tmp}/cxado-tenable-mcp.pid"
LOG_FILE="${TMPDIR:-/tmp}/cxado-tenable-mcp.log"

log() { printf '[cxado-up-tenable-mcp] %s\n' "$*"; }

if curl -sf -m 3 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
  log "already healthy on :${PORT}"
  exit 0
fi

if [[ ! -f "$TENABLE_DIR/.env" ]]; then
  log "WARN: $TENABLE_DIR/.env missing — copy from .env.example and set NESSUS_* credentials"
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  log "stopping previous process $(cat "$PID_FILE")"
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  sleep 1
fi

cd "$TENABLE_DIR"
MCP_PORT="$PORT" nohup uv run tenable-mcp serve >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
log "started pid $(cat "$PID_FILE"), log: $LOG_FILE"

for i in $(seq 1 30); do
  if curl -sf -m 3 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    log "healthy http://localhost:${PORT}/health"
    echo ""
    echo "In projects/egregore/.env:"
    echo "  NESSUS_MCP_ENABLED=true"
    echo "  NESSUS_MCP_URL=http://localhost:${PORT}/mcp"
    exit 0
  fi
  sleep 1
done

log "FAIL: server did not become healthy — see $LOG_FILE"
exit 1
