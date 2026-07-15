#!/usr/bin/env bash
# Remove per-project symlinks to shared/agent-rules (SSOT: meta .cursor/rules via cxado.code-workspace).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

remove_core_rule_symlinks() {
  local rules_dir="$1"
  [[ -d "$rules_dir" ]] || return 0
  local link
  for link in "$rules_dir"/core-*.mdc; do
    [[ -e "$link" ]] || continue
    [[ -L "$link" ]] || continue
    rm "$link"
    echo "  removed $link"
  done
}

for project in veil veneno fabrica egregore; do
  proj_dir="$ROOT/projects/$project"
  [[ -d "$proj_dir" ]] || continue
  echo "projects/$project"
  remove_core_rule_symlinks "$proj_dir/.cursor/rules"
  remove_core_rule_symlinks "$proj_dir/.agents/rules"
done

echo "Legacy shared/agent-rules symlinks removed (if any). Open cxado.code-workspace for core rules."
