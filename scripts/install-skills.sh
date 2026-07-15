#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_ROOT="$ROOT/shared/skills"
CURSOR_SKILLS="${HOME}/.cursor/skills"

if [[ ! -d "$SKILLS_ROOT" ]]; then
  echo "error: shared/skills not found; clone cxado meta-repo" >&2
  exit 1
fi

mkdir -p "$CURSOR_SKILLS"

install_skill() {
  local src="$1"
  local name
  name="$(basename "$src")"
  local dest="$CURSOR_SKILLS/$name"
  ln -sfn "$src" "$dest"
  echo "  $dest -> $src"
}

echo "Installing devsecops skills..."
for skill_dir in "$SKILLS_ROOT"/devsecops/*/; do
  [[ -d "$skill_dir" ]] || continue
  install_skill "$(cd "$skill_dir" && pwd)"
done

echo "Installing veil skills..."
for skill_dir in "$SKILLS_ROOT"/veil/*/; do
  [[ -d "$skill_dir" ]] || continue
  install_skill "$(cd "$skill_dir" && pwd)"
done

echo "Installing agent skills..."
for skill_dir in "$SKILLS_ROOT"/agent/*/; do
  [[ -d "$skill_dir" ]] || continue
  install_skill "$(cd "$skill_dir" && pwd)"
done

echo "Skills installed to $CURSOR_SKILLS"
