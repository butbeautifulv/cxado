#!/usr/bin/env bash
# Push a local submodule checkout to gitlab.svo.aero/av.popov/<repo> (one-time or sync).
#
# Creates the GitLab project via API if missing (needs GITLAB_PAT_RUNNER in secrets).
#
# Usage:
#   ./scripts/gitlab/push-submodule-mirror.sh projects/egregore
#   ./scripts/gitlab/push-submodule-mirror.sh projects/veil
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

SUB_PATH="${1:?usage: $0 <submodule-path> e.g. projects/egregore}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
GITLAB_PREFIX="${CI_SUBMODULE_GITLAB_PREFIX:-git@gitlab.svo.aero:av.popov}"
PAT="${GITLAB_PAT_RUNNER:-}"

if [[ ! -d "${ROOT}/${SUB_PATH}/.git" ]]; then
  echo "not a submodule checkout: ${ROOT}/${SUB_PATH}" >&2
  exit 2
fi

url="$(git config -f "${ROOT}/.gitmodules" --get "submodule.${SUB_PATH}.url")"
repo="$(basename "${url}" .git)"
gitlab_ssh="${GITLAB_PREFIX}/${repo}.git"

log() { printf '[push-submodule-mirror] %s\n' "$*"; }

if [[ -n "${PAT}" ]]; then
  ns_id="$(ssh "${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}" \
    "curl -sk --header 'PRIVATE-TOKEN: ${PAT}' '${GITLAB_URL}/api/v4/namespaces?search=av.popov'" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")"
  code="$(ssh "${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}" \
    "curl -sk -o /tmp/gl-create.json -w '%{http_code}' --request POST '${GITLAB_URL}/api/v4/projects' \
      --header 'PRIVATE-TOKEN: ${PAT}' --header 'Content-Type: application/json' \
      -d '{\"name\":\"${repo}\",\"path\":\"${repo}\",\"namespace_id\":${ns_id},\"visibility\":\"private\",\"description\":\"Mirror of butbeautifulv/${repo} for cxado corp CI\"}'")"
  if [[ "${code}" == "201" ]]; then
    log "created ${GITLAB_URL}/av.popov/${repo}"
  else
    log "project create HTTP ${code} (may already exist)"
  fi
fi

cd "${ROOT}/${SUB_PATH}"
branch="$(git branch --show-current)"
git remote remove gitlab 2>/dev/null || true
git remote add gitlab "${gitlab_ssh}"
log "push ${branch} -> ${gitlab_ssh}"
git push -u gitlab "${branch}"
log "done ${repo}"
