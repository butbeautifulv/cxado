#!/usr/bin/env bash
# Push a local submodule checkout to gitlab.svo.aero/av.popov/<repo> (one-time or sync).
#
# Supports nested submodules (e.g. projects/tabula/fstec). Creates GitLab projects via API.
#
# Usage:
#   ./scripts/gitlab/push-submodule-mirror.sh projects/egregore
#   ./scripts/gitlab/push-submodule-mirror.sh projects/tabula/fstec
#   ./scripts/gitlab/push-submodule-mirror.sh --all
#   ./scripts/gitlab/push-submodule-mirror.sh --all --recursive
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
GITLAB_PREFIX="${CI_SUBMODULE_GITLAB_PREFIX:-git@gitlab.svo.aero:av.popov}"
PAT="${GITLAB_PAT_RUNNER:-}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
PUSH_ALL=false
RECURSIVE=false
SUB_PATH="${1:-}"

log() { printf '[push-submodule-mirror] %s\n' "$*"; }

usage() {
  echo "usage: $0 <submodule-path> | --all [--recursive]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) PUSH_ALL=true; shift ;;
    --recursive) RECURSIVE=true; shift ;;
    -h|--help) usage ;;
    *)
      if [[ -z "${SUB_PATH}" || "${SUB_PATH}" == --* ]]; then
        SUB_PATH="$1"
      fi
      shift
      ;;
  esac
done

gitlab_api() {
  local method="$1" path="$2" body="${3:-}"
  local url="${GITLAB_URL%/}${path}"
  if [[ -n "${SSH_HOST}" ]]; then
    if [[ -n "${body}" ]]; then
      ssh "${SSH_HOST}" "curl -sk --connect-timeout 10 --request '${method}' '${url}' \
        --header 'PRIVATE-TOKEN: ${PAT}' --header 'Content-Type: application/json' \
        -d $(printf '%q' "${body}") -w '\nHTTP:%{http_code}\n'" 2>/dev/null || printf '\nHTTP:000\n'
    else
      ssh "${SSH_HOST}" "curl -sk --connect-timeout 10 --request '${method}' '${url}' \
        --header 'PRIVATE-TOKEN: ${PAT}' -w '\nHTTP:%{http_code}\n'" 2>/dev/null || printf '\nHTTP:000\n'
    fi
    return 0
  fi
  if [[ -n "${body}" ]]; then
    curl -sk --connect-timeout 5 --request "${method}" "${url}" \
      --header "PRIVATE-TOKEN: ${PAT}" \
      --header "Content-Type: application/json" \
      --data "${body}" \
      -w "\nHTTP:%{http_code}\n" 2>/dev/null || printf '\nHTTP:000\n'
  else
    curl -sk --connect-timeout 5 --request "${method}" "${url}" \
      --header "PRIVATE-TOKEN: ${PAT}" \
      -w "\nHTTP:%{http_code}\n" 2>/dev/null || printf '\nHTTP:000\n'
  fi
}

http_code() { echo "$1" | tail -1 | sed 's/HTTP://'; }

ensure_gitlab_project() {
  local repo="$1"
  [[ -n "${PAT}" ]] || return 0

  local out code ns_id
  out="$(gitlab_api GET "/api/v4/projects/av.popov%2F${repo}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  [[ "${code}" == "200" ]] && return 0
  [[ "${code}" == "000" || -z "${code}" ]] && { log "skip project create ${repo} (API via ${SSH_HOST})"; return 0; }

  out="$(gitlab_api GET "/api/v4/namespaces?search=av.popov" 2>/dev/null || true)"
  ns_id="$(echo "${out}" | sed '$d' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'])" 2>/dev/null || true)"
  [[ -n "${ns_id}" ]] || { log "WARN: namespace av.popov not found"; return 0; }

  code="$(gitlab_api POST "/api/v4/projects" \
    "{\"name\":\"${repo}\",\"path\":\"${repo}\",\"namespace_id\":${ns_id},\"visibility\":\"private\",\"description\":\"Corp mirror for cxado\"}" \
    | tail -1 | sed 's/HTTP://')"
  if [[ "${code}" == "201" ]]; then
    log "created ${GITLAB_URL}/av.popov/${repo}"
  else
    log "project create HTTP ${code} for ${repo}"
  fi
}

is_submodule_checkout() {
  [[ -e "${ROOT}/${1}/.git" ]]
}

repo_name_for_path() {
  local path="$1" url parent name
  if url="$(git config -f "${ROOT}/.gitmodules" --get "submodule.${path}.url" 2>/dev/null)"; then
    basename "${url}" .git
    return 0
  fi
  parent="$(dirname "${path}")"
  name="$(basename "${path}")"
  url="$(git config -f "${ROOT}/${parent}/.gitmodules" --get "submodule.${name}.url" 2>/dev/null || true)"
  [[ -n "${url}" ]] || return 1
  basename "${url}" .git
}

list_nested_paths() {
  local parent="$1" gm child
  gm="${ROOT}/${parent}/.gitmodules"
  [[ -f "${gm}" ]] || return 0
  while IFS= read -r child; do
    [[ -n "${child}" ]] || continue
    echo "${parent}/${child}"
  done < <(git config -f "${gm}" --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
}

list_all_paths() {
  local path child
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    if [[ "${RECURSIVE}" == true ]]; then
      while IFS= read -r child; do
        [[ -n "${child}" ]] || continue
        echo "${child}"
      done < <(list_nested_paths "${path}")
    fi
    echo "${path}"
  done < <(git config -f "${ROOT}/.gitmodules" --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
}

push_gitlab_with_lfs() {
  local branch="$1"
  if git rev-parse --git-dir >/dev/null 2>&1 && git lfs env >/dev/null 2>&1; then
    if git lfs ls-files 2>/dev/null | grep -q .; then
      log "git lfs push --all gitlab ${branch}"
      git lfs push --all gitlab "${branch}" || true
    fi
  fi
  git push -u gitlab "${branch}" --force-with-lease
}

push_with_gitmodules_overlay() {
  local branch="$1"
  local parent tip overlay tree
  if [[ ! -f .gitmodules.gitlab ]]; then
    push_gitlab_with_lfs "${branch}"
    return 0
  fi
  tip="$(git rev-parse HEAD)"
  cp .gitmodules.gitlab .gitmodules
  git add .gitmodules
  tree="$(git write-tree)"
  git checkout -- .gitmodules
  overlay="$(git commit-tree -p "${tip}" -m "chore(gitlab): corp nested submodule URLs" "${tree}")"
  log "push overlay ${overlay:0:12} (${branch})"
  git fetch gitlab "${branch}" 2>/dev/null || true
  if git rev-parse -q --verify "refs/remotes/gitlab/${branch}" >/dev/null 2>&1; then
    git push gitlab "${overlay}:refs/heads/${branch}" \
      --force-with-lease="refs/heads/${branch}:refs/remotes/gitlab/${branch}" 2>/dev/null \
      || git push gitlab "${overlay}:refs/heads/${branch}"
  else
    git push gitlab "${overlay}:refs/heads/${branch}"
  fi
}

push_one() {
  local path="$1" repo gitlab_ssh branch
  if ! is_submodule_checkout "${path}"; then
    echo "not a submodule checkout: ${ROOT}/${path}" >&2
    exit 2
  fi

  if [[ "${RECURSIVE}" == true ]]; then
    local nested
    while IFS= read -r nested; do
      [[ -n "${nested}" ]] || continue
      if is_submodule_checkout "${nested}"; then
        push_one "${nested}"
      fi
    done < <(list_nested_paths "${path}")
  fi

  repo="$(repo_name_for_path "${path}")" || die_path "${path}"
  gitlab_ssh="${GITLAB_PREFIX}/${repo}.git"
  ensure_gitlab_project "${repo}"

  cd "${ROOT}/${path}"
  branch="$(git branch --show-current)"
  git remote remove gitlab 2>/dev/null || true
  git remote add gitlab "${gitlab_ssh}"
  log "push ${path} (${branch}) -> ${gitlab_ssh}"
  push_with_gitmodules_overlay "${branch}"
  log "done ${repo}"
  cd "${ROOT}"
}

die_path() {
  echo "cannot resolve repo name for submodule path: ${1}" >&2
  exit 2
}

if [[ "${PUSH_ALL}" == true ]]; then
  declare -A pushed=()
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    [[ -n "${pushed[$path]+x}" ]] && continue
    pushed[$path]=1
    if is_submodule_checkout "${path}"; then
      push_one "${path}"
    else
      log "skip ${path} (not initialized)"
    fi
  done < <(list_all_paths | awk '!seen[$0]++')
elif [[ -z "${SUB_PATH}" ]]; then
  usage
else
  push_one "${SUB_PATH}"
fi
