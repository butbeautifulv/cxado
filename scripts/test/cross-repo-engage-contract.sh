#!/usr/bin/env bash
# Cross-repo contract: veneno engage.events schemas match veil pipeline consumer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VEIL="$ROOT/projects/veil"
CONTRACTS="$ROOT/shared/contracts"

cd "$VEIL/pipeline/connector/nats" && go test -run Contract -count=1 .

python3 - "$CONTRACTS" <<'PY'
import json
import sys
from pathlib import Path

contracts = Path(sys.argv[1])

def load(name: str) -> dict:
    return json.loads((contracts / name).read_text())

def check_required(payload: dict, schema: dict, label: str) -> None:
    required = schema.get("required", [])
    props = schema.get("properties", {})
    extra = set(payload) - set(props)
    if schema.get("additionalProperties") is False and extra:
        raise SystemExit(f"{label}: unexpected keys {sorted(extra)}")
    missing = [k for k in required if k not in payload]
    if missing:
        raise SystemExit(f"{label}: missing required {missing}")

audit_schema = load("engage-events-audit.json")
finding_schema = load("engage-events-finding.json")
audit = {
    "source": "veneno",
    "tool": "nmap",
    "target": "127.0.0.1",
    "subject": "t",
    "success": True,
    "at": "2026-06-23T12:00:00Z",
}
finding = {
    "tool": "nuclei",
    "target": "https://x",
    "title": "xss",
    "severity": "high",
}
check_required(audit, audit_schema, "engage.events.audit")
check_required(finding, finding_schema, "engage.events.finding")
print("engage.events sample payloads OK vs shared/contracts")
PY

echo "cross-repo engage.events contract OK"
