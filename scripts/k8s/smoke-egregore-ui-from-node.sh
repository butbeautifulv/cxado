#!/usr/bin/env bash
# Smoke: egregore Next.js UI API proxy from a client node (corp network / k3s :30301).
set -euo pipefail

BASE="${1:-https://10.8.185.15:30301}"
CURL=(curl -k -sfS --max-time 25)

echo "==> health"
"${CURL[@]}" "$BASE/api/egregore/health" | head -c 200
echo

echo "==> engagements (limit=1)"
"${CURL[@]}" "$BASE/api/egregore/v1/engagements?tenant_id=default&limit=1" | head -c 400
echo

echo "==> memory (limit=1)"
"${CURL[@]}" "$BASE/api/egregore/v1/memory?limit=1" | head -c 400
echo

echo "OK: $BASE"
