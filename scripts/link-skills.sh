#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB="$ROOT/shared/skills"

if [[ ! -d "$HUB/devsecops" ]]; then
  echo "error: shared/skills submodule not initialized; run make bootstrap first" >&2
  exit 1
fi

link_skill_namespace() {
  local namespace_dir="$1"
  local target_parent="$2"
  local skill_dir name rel_target

  mkdir -p "$target_parent"
  echo "Linking skills in $target_parent"
  for skill_dir in "$namespace_dir"/*/; do
    [[ -d "$skill_dir" ]] || continue
    name="$(basename "$skill_dir")"
    rel_target="$(realpath --relative-to="$target_parent" "$skill_dir")"
    rm -rf "$target_parent/$name"
    ln -sfn "$rel_target" "$target_parent/$name"
    echo "  $target_parent/$name -> $rel_target"
  done
}

link_skill_namespace "$HUB/devsecops" "$ROOT/projects/fabrica/.agents/skills"

echo "Project skill symlinks created."
