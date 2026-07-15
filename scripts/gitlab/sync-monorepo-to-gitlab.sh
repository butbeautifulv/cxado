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
#   2. Merge into gitlab/main + apply .gitmodules.gitlab (fast-forward, protected-branch safe)
#   3. Restore local .gitmodules (GitHub URLs) — working tree identical to before
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

# shellcheck source=scripts/gitlab/lib/remotes.sh
source "${ROOT}/scripts/gitlab/lib/remotes.sh"

SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

GITLAB_REMOTE="${GITLAB_REMOTE:-${GITLAB_REMOTE_NAME}}"
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
  log "adding ephemeral remote ${GITLAB_REMOTE} -> ${GITLAB_MONOREPO_URL}"
  ensure_gitlab_remote_ephemeral "${ROOT}" "${GITLAB_MONOREPO_URL}"
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
  if [[ ! -e "${path}/.git" ]]; then
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
  # Never leave GitHub URLs replaced on the dev branch
  if [[ -f "${ROOT}/.gitmodules.github" ]]; then
    cp "${ROOT}/.gitmodules.github" .gitmodules
  else
    git checkout -- .gitmodules 2>/dev/null || git restore .gitmodules 2>/dev/null || true
  fi
  git submodule sync --recursive 2>/dev/null || true
}

trap restore_gitmodules EXIT

push_monorepo_gitlab_view() {
  local parent saved_branch remote_tip work_branch
  parent="$(git rev-parse HEAD)"
  saved_branch="$(git branch --show-current)"
  work_branch="cxado-gitlab-sync-$$"

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] would merge ${parent:0:12} into ${GITLAB_REMOTE}/${GITLAB_BRANCH} + .gitmodules.gitlab"
    return 0
  fi

  git fetch "${GITLAB_REMOTE}" "${GITLAB_BRANCH}" 2>/dev/null || true
  remote_tip=""
  if git rev-parse -q --verify "refs/remotes/${GITLAB_REMOTE}/${GITLAB_BRANCH}" >/dev/null 2>&1; then
    remote_tip="$(git rev-parse "refs/remotes/${GITLAB_REMOTE}/${GITLAB_BRANCH}")"
  fi

  if [[ -n "${remote_tip}" && "${remote_tip}" != "${parent}" ]]; then
    log "merge github ${parent:0:12} into gitlab tip ${remote_tip:0:12}"
    git checkout -B "${work_branch}" "${remote_tip}"
    git merge --no-edit -m "chore(gitlab): sync monorepo ${parent:0:12}" "${parent}"
  elif [[ -n "${remote_tip}" && "${remote_tip}" == "${parent}" ]]; then
    log "gitlab tip matches github HEAD — update .gitmodules only"
    git checkout -B "${work_branch}" "${remote_tip}"
  else
    log "first push to ${GITLAB_REMOTE}/${GITLAB_BRANCH}"
    git checkout -B "${work_branch}" "${parent}"
  fi

  cp "${GITMODULES_GITLAB}" .gitmodules
  git add .gitmodules
  if git diff --cached --quiet; then
    log "no .gitmodules change on gitlab view"
  else
    git commit -m "chore(gitlab): corp-isolated submodule URLs"
  fi

  git push "${GITLAB_REMOTE}" "HEAD:refs/heads/${GITLAB_BRANCH}"
  log "pushed ${GITLAB_REMOTE}/${GITLAB_BRANCH} ($(git rev-parse --short HEAD))"

  if [[ -n "${saved_branch}" ]]; then
    git checkout "${saved_branch}"
  else
    git checkout "${parent}"
  fi
  git branch -D "${work_branch}" 2>/dev/null || true
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
  remove_gitlab_remote_in_repo "${ROOT}"
  log "done — local .gitmodules still GitHub; push GitHub: ./scripts/gitlab/push-github.sh"
}

main "$@"
