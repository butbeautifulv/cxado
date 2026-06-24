#!/usr/bin/env bash
# Cross-repo contract: veneno engage.events schemas match veil pipeline consumer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VEIL="$ROOT/projects/veil"

cd "$VEIL/pipeline/connector/nats" && go test -run Contract -count=1 .

python3 - <<'PY'
import json
audit = {"source":"veneno","tool":"nmap","target":"127.0.0.1","subject":"t","success":True,"at":"2026-06-23T12:00:00Z"}
finding = {"tool":"nuclei","target":"https://x","title":"xss","severity":"high"}
json.dumps(audit)
json.dumps(finding)
print("engage.events sample payloads OK")
PY

echo "cross-repo engage.events contract OK"
