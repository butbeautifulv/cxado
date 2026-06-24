#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB="$ROOT/shared/agent-rules"

if [[ ! -d "$HUB/core" ]]; then
  echo "error: shared/agent-rules submodule not initialized; run make bootstrap first" >&2
  exit 1
fi

link_core_rule() {
  local symlink_name="$1"
  local core_file="$2"
  local target_dir="$3"
  local rel_target
  rel_target="$(realpath --relative-to="$target_dir" "$HUB/core/$core_file")"
  mkdir -p "$target_dir"
  ln -sfn "$rel_target" "$target_dir/$symlink_name"
  echo "  $target_dir/$symlink_name -> $rel_target"
}

# core file -> symlink name (from manifest.yaml)
declare -A RULES=(
  [karpathy-guidelines.mdc]=core-karpathy-guidelines.mdc
  [workflow-chain.mdc]=core-workflow-chain.mdc
  [parallel-branches.mdc]=core-parallel-branches.mdc
  [agent-critic.mdc]=core-agent-critic.mdc
  [kaizen.mdc]=core-kaizen.mdc
  [agent-documentation.mdc]=core-agent-documentation.mdc
)

link_project() {
  local rules_dir="$1"
  echo "Linking core rules in $rules_dir"
  for core_file in "${!RULES[@]}"; do
    link_core_rule "${RULES[$core_file]}" "$core_file" "$rules_dir"
  done
}

link_project "$ROOT/projects/veil/.cursor/rules"
link_project "$ROOT/projects/egregore/.agents/rules"
link_project "$ROOT/projects/veneno/.agents/rules"
link_project "$ROOT/projects/fabrica/.agents/rules"

echo "Agent rules symlinks created."
