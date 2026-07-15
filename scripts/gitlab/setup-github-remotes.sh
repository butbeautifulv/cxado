#!/usr/bin/env bash
# Normalize local remotes: origin = GitHub only, no persistent gitlab remote.
#
# Run after clone, after corp sync, or when agents confuse gitlab vs origin:
#   ./scripts/gitlab/setup-github-remotes.sh
#   ./scripts/gitlab/setup-github-remotes.sh --submodules-only
#
# Corp push (adds gitlab temporarily inside sync scripts):
#   ./scripts/gitlab/sync-monorepo-to-gitlab.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/gitlab/lib/remotes.sh
source "${ROOT}/scripts/gitlab/lib/remotes.sh"

SUBMODULES_ONLY=false
log() { printf '[setup-github-remotes] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --submodules-only) SUBMODULES_ONLY=true; shift ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

restore_github_gitmodules "${ROOT}"
log "restored .gitmodules from .gitmodules.github"

if [[ "${SUBMODULES_ONLY}" != true ]]; then
  ensure_origin_github_in_repo "${ROOT}" "${GITHUB_MONOREPO_URL}"
  log "monorepo: origin -> GitHub, removed gitlab remote"
fi

path=""
while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  if [[ ! -e "${ROOT}/${path}/.git" ]]; then
    log "skip ${path} (not initialized)"
    continue
  fi
  url="$(github_url_for_submodule_path "${ROOT}" "${path}")" || {
    log "skip ${path} (no GitHub url in .gitmodules.github)"
    continue
  }
  ensure_origin_github_in_repo "${ROOT}/${path}" "${url}"
  log "submodule ${path}: origin -> ${url}"
done < <(list_submodule_paths "${ROOT}")

log "done — push dev: git push origin main  |  corp: ./scripts/gitlab/sync-monorepo-to-gitlab.sh"
