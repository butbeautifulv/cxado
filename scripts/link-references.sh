#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$ROOT/shared/references"

if [[ ! -d "$REF" ]]; then
  echo "error: shared/references submodule not initialized; run make bootstrap first" >&2
  exit 1
fi

link_ref() {
  local project="$1"
  local target="$ROOT/projects/$project/refs"
  mkdir -p "$(dirname "$target")"
  ln -sfn "$REF" "$target"
  echo "  $target -> $REF"
}

link_ref veil
link_ref fabrica

echo "Reference symlinks created."
