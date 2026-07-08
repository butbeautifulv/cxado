#!/usr/bin/env bash
# Push a local submodule checkout to gitlab.svo.aero/av.popov/<repo> (one-time or sync).
#
# Creates the GitLab project via API if missing (needs GITLAB_PAT_RUNNER in secrets).
#
# Usage:
#   ./scripts/gitlab/push-submodule-mirror.sh projects/egregore
#   ./scripts/gitlab/push-submodule-mirror.sh --all
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
GITLAB_PREFIX="${CI_SUBMODULE_GITLAB_PREFIX:-git@gitlab.svo.aero:av.popov}"
PAT="${GITLAB_PAT_RUNNER:-}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
PUSH_ALL=false
SUB_PATH="${1:-}"

log() { printf '[push-submodule-mirror] %s\n' "$*"; }

usage() {
  echo "usage: $0 <submodule-path> | --all" >&2
  exit 2
}

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

ensure_gitlab_project() {
  local repo="$1"
  [[ -n "${PAT}" ]] || return 0

  local out code
  out="$(gitlab_api GET "/api/v4/projects/av.popov%2F${repo}" 2>/dev/null || true)"
  code="$(echo "${out}" | tail -1 | sed 's/HTTP://')"
  if [[ "${code}" == "200" ]]; then
    return 0
  fi
  if [[ "${code}" == "000" || -z "${code}" ]]; then
    log "GitLab API unreachable — skip project create for ${repo} (set CXADO_OFFLINE_SSH_HOST or run from corp)"
    return 0
  fi

  local ns_out ns_id
  ns_out="$(gitlab_api GET "/api/v4/namespaces?search=av.popov" 2>/dev/null || true)"
  if ! ns_id="$(echo "${ns_out}" | sed '$d' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'])" 2>/dev/null)"; then
    log "WARN: cannot resolve namespace — skip project create for ${repo}"
    return 0
  fi

  code="$(gitlab_api POST "/api/v4/projects" \
    "{\"name\":\"${repo}\",\"path\":\"${repo}\",\"namespace_id\":${ns_id},\"visibility\":\"private\",\"description\":\"Corp mirror of ${repo} for cxado (no outbound GitHub)\"}" \
    | tail -1 | sed 's/HTTP://')"
  if [[ "${code}" == "201" ]]; then
    log "created ${GITLAB_URL}/av.popov/${repo}"
  else
    log "project create HTTP ${code} for ${repo} (may already exist)"
  fi
}

is_submodule_checkout() {
  [[ -e "${ROOT}/${1}/.git" ]]
}

push_one() {
  local path="$1"
  if ! is_submodule_checkout "${path}"; then
    echo "not a submodule checkout: ${ROOT}/${path}" >&2
    exit 2
  fi

  local url repo gitlab_ssh branch
  url="$(git config -f "${ROOT}/.gitmodules" --get "submodule.${path}.url")"
  repo="$(basename "${url}" .git)"
  gitlab_ssh="${GITLAB_PREFIX}/${repo}.git"

  ensure_gitlab_project "${repo}"

  cd "${ROOT}/${path}"
  branch="$(git branch --show-current)"
  git remote remove gitlab 2>/dev/null || true
  git remote add gitlab "${gitlab_ssh}"
  log "push ${path} (${branch}) -> ${gitlab_ssh}"
  git push -u gitlab "${branch}" --force-with-lease
  log "done ${repo}"
}

if [[ "${SUB_PATH}" == "--all" ]]; then
  PUSH_ALL=true
elif [[ -z "${SUB_PATH}" ]]; then
  usage
fi

if [[ "${PUSH_ALL}" == true ]]; then
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    if is_submodule_checkout "${path}"; then
      push_one "${path}"
    else
      log "skip ${path} (not initialized)"
    fi
  done < <(git config -f "${ROOT}/.gitmodules" --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
else
  push_one "${SUB_PATH}"
fi
