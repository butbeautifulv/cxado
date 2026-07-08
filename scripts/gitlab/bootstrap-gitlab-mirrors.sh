#!/usr/bin/env bash
# Create all GitLab mirror projects from .gitmodules.gitlab and push initialized submodules.
#
# Uses P30 SSH hop for GitLab API (corp network). Safe to re-run.
#
# Usage:
#   ./scripts/gitlab/bootstrap-gitlab-mirrors.sh
#   ./scripts/gitlab/bootstrap-gitlab-mirrors.sh --push-only   # skip project create
#   ./scripts/gitlab/bootstrap-gitlab-mirrors.sh --create-only   # only create empty projects
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
PAT="${GITLAB_PAT_RUNNER:-}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
GITMODULES="${ROOT}/.gitmodules.gitlab"
PUSH_ONLY=false
CREATE_ONLY=false

log() { printf '[bootstrap-gitlab-mirrors] %s\n' "$*"; }
die() { echo "[bootstrap-gitlab-mirrors] ERROR: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push-only) PUSH_ONLY=true; shift ;;
    --create-only) CREATE_ONLY=true; shift ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -f "${GITMODULES}" ]] || die "missing ${GITMODULES}"
[[ -n "${PAT}" ]] || die "missing GITLAB_PAT_RUNNER in ${SECRETS}"

gitlab_api() {
  local method="$1" path="$2" body="${3:-}"
  local url="${GITLAB_URL%/}${path}"
  if [[ -n "${body}" ]]; then
    ssh "${SSH_HOST}" "curl -sk --request '${method}' '${url}' \
      --header 'PRIVATE-TOKEN: ${PAT}' --header 'Content-Type: application/json' \
      -d $(printf '%q' "${body}") -w '\nHTTP:%{http_code}\n'"
  else
    ssh "${SSH_HOST}" "curl -sk --request '${method}' '${url}' \
      --header 'PRIVATE-TOKEN: ${PAT}' -w '\nHTTP:%{http_code}\n'"
  fi
}

http_code() { echo "$1" | tail -1 | sed 's/HTTP://'; }

list_mirror_repos() {
  git config -f "${GITMODULES}" --get-regexp '^submodule\..*\.url$' \
    | awk '{print $2}' | while read -r url; do basename "${url}" .git; done
}

ensure_project() {
  local repo="$1"
  local out code ns_id
  out="$(gitlab_api GET "/api/v4/projects/av.popov%2F${repo}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  if [[ "${code}" == "200" ]]; then
    log "exists: av.popov/${repo}"
    return 0
  fi

  out="$(gitlab_api GET "/api/v4/namespaces?search=av.popov" 2>/dev/null || true)"
  ns_id="$(echo "${out}" | sed '$d' | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'])")"

  local body
  body="$(cat <<EOF
{"name":"${repo}","path":"${repo}","namespace_id":${ns_id},"visibility":"private","description":"Corp mirror for cxado — no outbound GitHub"}
EOF
)"
  out="$(gitlab_api POST "/api/v4/projects" "${body}")"
  code="$(http_code "${out}")"
  if [[ "${code}" == "201" ]]; then
    log "created: ${GITLAB_URL}/av.popov/${repo}"
  elif [[ "${code}" == "400" ]]; then
    log "already exists or rejected: av.popov/${repo} (HTTP ${code})"
  else
    echo "${out}" >&2
    die "failed to create av.popov/${repo} HTTP ${code}"
  fi
}

create_all_projects() {
  local repo
  for repo in $(list_mirror_repos); do
    ensure_project "${repo}"
  done
}

push_all_submodules() {
  "${ROOT}/scripts/gitlab/push-submodule-mirror.sh" --all
}

main() {
  log "GitLab mirrors under av.popov (API via ${SSH_HOST})"
  if [[ "${PUSH_ONLY}" != true ]]; then
    create_all_projects
  fi
  if [[ "${CREATE_ONLY}" != true ]]; then
    push_all_submodules
  fi
  log "done — list: ssh ${SSH_HOST} \"curl -sk -H PRIVATE-TOKEN:... ${GITLAB_URL}/api/v4/users/av.popov/projects?per_page=100\""
}

main "$@"
