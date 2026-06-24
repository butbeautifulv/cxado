#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BROKER="$ROOT/shared/go/auth-broker"

if [[ ! -f "$BROKER/go.mod" ]]; then
  echo "skip: shared/go/auth-broker not present"
  exit 0
fi

echo "auth-broker link stub: use go.mod replace in consumer projects"
echo "  replace github.com/butbeautifulv/cxado/shared/go/auth-broker => ../../../shared/go/auth-broker"
