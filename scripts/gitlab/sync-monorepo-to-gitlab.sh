#!/usr/bin/env bash
# Push an isolated corp copy to gitlab.svo.aero — GitLab submodule URLs only, no GitHub refs.
#
# GitHub workflow is unchanged:
#   git push origin main          # or: ./scripts/gitlab/push-github.sh
#
# Corp / CI sync (from laptop with GitHub + GitLab access):
#   ./scripts/gitlab/sync-monorepo-to-gitlab.sh
#   ./scripts/gitlab/sync-monorepo-to-gitlab.sh --only projects/egregore,projects/veil
#   ./scripts/gitlab/sync-monorepo-to-gitlab.sh --skip-submodules   # monorepo + .gitmodules only
#
# What it does:
#   1. Push submodule commits to gitlab.svo.aero/av.popov/<repo> mirrors
#   2. Build a one-commit overlay on HEAD with .gitmodules.gitlab → push to gitlab main
#   3. Restore local .gitmodules (GitHub URLs) — working tree identical to before
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

GITLAB_REMOTE="${GITLAB_REMOTE:-gitlab}"
GITLAB_BRANCH="${GITLAB_BRANCH:-main}"
GITMODULES_GITLAB="${ROOT}/.gitmodules.gitlab"
SKIP_SUBMODULES=false
DRY_RUN=false
ONLY_PATHS=""

log() { printf '[sync-gitlab] %s\n' "$*"; }
die() { echo "[sync-gitlab] ERROR: $*" >&2; exit 2; }

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY_PATHS="${2:-}"; shift 2 ;;
    --skip-submodules) SKIP_SUBMODULES=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1 (try --help)" ;;
  esac
done

[[ -f "${GITMODULES_GITLAB}" ]] || die "missing ${GITMODULES_GITLAB}"

if ! git remote get-url "${GITLAB_REMOTE}" >/dev/null 2>&1; then
  die "remote '${GITLAB_REMOTE}' not configured — git remote add gitlab git@gitlab.svo.aero:av.popov/cxado.git"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  die "working tree not clean — commit or stash before sync"
fi

list_submodule_paths() {
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}'
}

paths_to_sync() {
  if [[ -n "${ONLY_PATHS}" ]]; then
    echo "${ONLY_PATHS}" | tr ',' ' '
  else
    list_submodule_paths
  fi
}

ensure_submodule_init() {
  local path="$1"
  if [[ ! -d "${path}/.git" ]]; then
    log "init submodule ${path} (GitHub url for local checkout)"
    git submodule update --init --depth 1 "${path}"
  fi
}

push_submodules() {
  local path
  for path in $(paths_to_sync); do
    if ! git config -f .gitmodules --get "submodule.${path}.url" >/dev/null 2>&1; then
      log "skip unknown submodule path: ${path}"
      continue
    fi
    ensure_submodule_init "${path}"
    if [[ "${DRY_RUN}" == true ]]; then
      log "[dry-run] push-submodule-mirror.sh ${path}"
    else
      "${ROOT}/scripts/gitlab/push-submodule-mirror.sh" "${path}"
    fi
  done
}

restore_gitmodules() {
  git checkout -- .gitmodules 2>/dev/null || git restore .gitmodules 2>/dev/null || true
  git submodule sync --recursive 2>/dev/null || true
}

trap restore_gitmodules EXIT

push_monorepo_gitlab_view() {
  local parent tree commit
  parent="$(git rev-parse HEAD)"

  cp "${GITMODULES_GITLAB}" .gitmodules
  git add .gitmodules
  tree="$(git write-tree)"
  git checkout -- .gitmodules

  commit="$(
    GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-$(git config user.name || echo cxado-sync)}"
    GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config user.email || echo cxado-sync@local)}"
    GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
    GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"
    export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
    git commit-tree -p "${parent}" -m "chore(gitlab): corp-isolated submodule URLs" "${tree}"
  )"

  log "gitlab overlay commit ${commit:0:12} (parent ${parent:0:12})"
  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] would push ${GITLAB_REMOTE} ${commit}:${GITLAB_BRANCH}"
    return 0
  fi
  git push "${GITLAB_REMOTE}" "${commit}:refs/heads/${GITLAB_BRANCH}"
  log "pushed ${GITLAB_REMOTE}/${GITLAB_BRANCH}"
}

main() {
  log "sync corp copy → ${GITLAB_REMOTE}/${GITLAB_BRANCH} (GitHub origin untouched)"
  if [[ "${SKIP_SUBMODULES}" != true ]]; then
    push_submodules
  else
    log "skip submodule mirror push (--skip-submodules)"
  fi
  push_monorepo_gitlab_view
  trap - EXIT
  restore_gitmodules
  log "done — local .gitmodules still GitHub; push GitHub: ./scripts/gitlab/push-github.sh"
}

main "$@"
