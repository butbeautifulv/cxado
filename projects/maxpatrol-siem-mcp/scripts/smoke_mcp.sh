#!/usr/bin/env bash
# Smoke: maxpatrol-siem-mcp health + MCP tools/list (requires server on :8094).
set -euo pipefail

BASE="${SIEM_MCP_URL:-http://localhost:8094}"
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

if echo "$response" | grep -q 'investigate_incident'; then
  echo "OK: tools/list includes investigate_incident"
else
  echo "FAIL: investigate_incident not in tools/list" >&2
  echo "$response" | head -c 500 >&2
  exit 1
fi
