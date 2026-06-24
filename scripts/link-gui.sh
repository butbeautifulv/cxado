#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUI="$ROOT/shared/gui"

if [[ ! -f "$GUI/package.json" ]]; then
  echo "error: shared/gui submodule not initialized; run make bootstrap first" >&2
  exit 1
fi

link_gui_project() {
  local project="$1"
  local project_dir="$ROOT/projects/$project"
  local pkg_dir="$project_dir/node_modules/@cxado"

  if [[ ! -d "$project_dir" ]]; then
    echo "skip: projects/$project not present"
    return 0
  fi

  mkdir -p "$pkg_dir"
  rm -rf "$pkg_dir/gui"
  ln -sfn "$(realpath "$GUI")" "$pkg_dir/gui"
  echo "  $pkg_dir/gui -> $(realpath "$GUI")"
}

echo "Linking @cxado/gui into pilot projects"
link_gui_project veil
link_gui_project tabula/fstec

echo "GUI symlinks created."
