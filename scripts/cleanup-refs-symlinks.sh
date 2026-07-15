#!/usr/bin/env bash
# Remove legacy projects/*/refs symlinks (SSOT: cxado root refs/).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for project in veil fabrica veneno egregore; do
  target="$ROOT/projects/$project/refs"
  if [[ -L "$target" ]]; then
    rm "$target"
    echo "  removed symlink $target"
  elif [[ -e "$target" ]]; then
    echo "  warn: $target exists and is not a symlink — left in place" >&2
  fi
done

echo "Legacy project refs symlinks cleaned (canonical: $ROOT/refs/)."
