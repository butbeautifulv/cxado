#!/usr/bin/env bash
# Start defectdojo-mcp HTTP server on :8096 (host process, not Docker).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD_DIR="$ROOT/projects/precursor/defectdojo-mcp"
PORT="${DEFECTDOJO_MCP_PORT:-8096}"
PID_FILE="${TMPDIR:-/tmp}/cxado-defectdojo-mcp.pid"
LOG_FILE="${TMPDIR:-/tmp}/cxado-defectdojo-mcp.log"

log() { printf '[cxado-up-defectdojo-mcp] %s\n' "$*"; }

if curl -sf -m 3 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
  log "already healthy on :${PORT}"
  exit 0
fi

if [[ ! -f "$DD_DIR/.env" ]]; then
  log "WARN: $DD_DIR/.env missing — copy from .env.example and set DEFECTDOJO_* credentials"
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  log "stopping previous process $(cat "$PID_FILE")"
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  sleep 1
fi

cd "$DD_DIR"
uv sync --all-groups >/dev/null
MCP_PORT="$PORT" nohup uv run defectdojo-mcp serve >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
log "started pid $(cat "$PID_FILE"), log: $LOG_FILE"

for i in $(seq 1 30); do
  if curl -sf -m 3 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    log "healthy http://localhost:${PORT}/health"
    echo ""
    echo "MCP: http://localhost:${PORT}/mcp"
    exit 0
  fi
  sleep 1
done

log "FAIL: server did not become healthy — see $LOG_FILE"
exit 1
