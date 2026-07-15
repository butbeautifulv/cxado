#!/usr/bin/env bash
# Move submodule git dir from .git/modules/... into projects/<name>/.git (embedded).
# Fixes Cursor/VS Code Source Control not listing submodule repos.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

embed_one() {
  local path="$1"
  local name
  name="$(basename "$path")"
  local wt="$ROOT/$path"
  local mod="$ROOT/.git/modules/$path"

  if [[ ! -d "$wt" ]]; then
    echo "skip: $path (missing worktree)" >&2
    return 0
  fi

  if [[ -d "$wt/.git" && ! -f "$wt/.git" ]]; then
    echo "ok: $path already embedded"
    return 0
  fi

  if [[ ! -d "$mod" ]]; then
    echo "error: $path — no $mod" >&2
    return 1
  fi

  rm -f "$wt/.git"
  mv "$mod" "$wt/.git"
  sed -i '/^[[:space:]]*worktree = /d' "$wt/.git/config"
  echo "embedded: $path"
}

if [[ $# -eq 0 ]]; then
  set -- projects/veil projects/veneno projects/egregore projects/fabrica
fi

for path in "$@"; do
  embed_one "$path"
done
