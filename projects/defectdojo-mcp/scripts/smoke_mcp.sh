#!/usr/bin/env bash
# Smoke: defectdojo-mcp health + MCP tools/list (requires server on :8096).
set -euo pipefail

BASE="${DEFECTDOJO_MCP_URL:-http://localhost:8096}"
HEALTH_URL="${BASE%/mcp}/health"
MCP_URL="${BASE%/mcp}/mcp"

if ! curl -sf -m 5 "$HEALTH_URL" >/dev/null; then
  echo "FAIL: health check $HEALTH_URL" >&2
  exit 1
fi
echo "OK: $HEALTH_URL"

payload='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
response="$(curl -sf -m 15 -X POST "$MCP_URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d "$payload")"

if echo "$response" | grep -q 'list_findings'; then
  echo "OK: tools/list includes list_findings"
else
  echo "FAIL: list_findings not in tools/list" >&2
  echo "$response" | head -c 500 >&2
  exit 1
fi
