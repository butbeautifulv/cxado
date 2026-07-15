#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

git submodule update --init --recursive
"$ROOT/scripts/cleanup-refs-symlinks.sh"
"$ROOT/scripts/link-skills.sh"
"$ROOT/scripts/install-skills.sh"
"$ROOT/scripts/link-gui.sh"

echo "cxado bootstrap complete."
