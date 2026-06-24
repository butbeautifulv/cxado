#!/usr/bin/env bash
# Smoke: auth-broker JSON contract examples are well-formed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEMA="$ROOT/shared/contracts/auth-broker-token-v1.json"

python3 - "$SCHEMA" <<'PY'
import json
import sys
from pathlib import Path

schema = json.loads(Path(sys.argv[1]).read_text())
req = schema["$defs"]["TokenRequest"]["examples"][0]
resp = schema["$defs"]["TokenResponse"]["examples"][0]
for label, payload in ("request", req), ("response", resp):
    if not isinstance(payload, dict):
        raise SystemExit(f"{label}: not an object")
print("auth-broker contract smoke: ok")
PY
