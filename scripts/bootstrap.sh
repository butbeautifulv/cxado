#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git submodule update --init --recursive
"$ROOT/scripts/link-references.sh"
"$ROOT/scripts/link-agent-rules.sh"
"$ROOT/scripts/link-skills.sh"
"$ROOT/scripts/install-skills.sh"

echo "cxado bootstrap complete."
