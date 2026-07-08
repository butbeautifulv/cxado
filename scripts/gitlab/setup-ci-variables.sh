#!/usr/bin/env bash
# Seed GitLab CI/CD variables for cxado → k3s pipeline (via P30 API hop).
#
# Usage:
#   ./scripts/gitlab/setup-ci-variables.sh
#   ./scripts/gitlab/setup-ci-variables.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
PROJECT_ID="${GITLAB_PROJECT_ID:-1938}"
PAT="${GITLAB_PAT_RUNNER:-}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
DRY_RUN=false

log() { printf '[setup-ci-variables] %s\n' "$*"; }
die() { echo "[setup-ci-variables] ERROR: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "${PAT}" ]] || die "missing GITLAB_PAT_RUNNER in ${SECRETS}"

# key|masked|protected
VARS=(
  "POSTGRES_PASSWORD|true|false"
  "REDIS_PASSWORD|true|false"
  "BUS_SIGNING_KEY|true|false"
  "CXADO_OFFLINE_SUDO_PW|true|false"
  "NEXUS_USER|true|false"
  "NEXUS_PASSWORD|true|false"
  "VM_01_PWD|true|false"
  "VM_02_PWD|true|false"
)

value_for() {
  case "$1" in
    POSTGRES_PASSWORD) echo "${POSTGRES_PASSWORD:-}" ;;
    REDIS_PASSWORD) echo "${REDIS_PASSWORD:-}" ;;
    BUS_SIGNING_KEY) echo "${BUS_SIGNING_KEY:-}" ;;
    CXADO_OFFLINE_SUDO_PW) echo "${CXADO_OFFLINE_SUDO_PW:-}" ;;
    NEXUS_USER) echo "${NEXUS_USER:-}" ;;
    NEXUS_PASSWORD) echo "${NEXUS_PASSWORD:-}" ;;
    VM_01_PWD) echo "${VM_01_PWD:-}" ;;
    VM_02_PWD) echo "${VM_02_PWD:-}" ;;
    *) return 1 ;;
  esac
}

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

upsert_var() {
  local key="$1" masked="$2" protected="$3" value="$4"
  [[ -n "${value}" ]] || { log "skip ${key} (empty in ${SECRETS})"; return 0; }

  local body code out
  body="$(KEY="${key}" VAL="${value}" MASKED="${masked}" PROTECTED="${protected}" python3 -c '
import json, os
print(json.dumps({
  "key": os.environ["KEY"],
  "value": os.environ["VAL"],
  "masked": os.environ["MASKED"] == "true",
  "protected": os.environ["PROTECTED"] == "true",
}))
')"

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] set ${key} (masked=${masked})"
    return 0
  fi

  out="$(gitlab_api GET "/api/v4/projects/${PROJECT_ID}/variables/${key}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  if [[ "${code}" == "200" ]]; then
    out="$(gitlab_api PUT "/api/v4/projects/${PROJECT_ID}/variables/${key}" "${body}")"
    code="$(http_code "${out}")"
    [[ "${code}" == "200" ]] || die "update ${key} HTTP ${code}"
    log "updated ${key}"
  else
    out="$(gitlab_api POST "/api/v4/projects/${PROJECT_ID}/variables" "${body}")"
    code="$(http_code "${out}")"
    [[ "${code}" == "201" ]] || die "create ${key} HTTP ${code}"
    log "created ${key}"
  fi
}

main() {
  log "project ${GITLAB_URL}/av.popov/cxado (id ${PROJECT_ID})"
  local spec key masked protected val
  for spec in "${VARS[@]}"; do
    IFS='|' read -r key masked protected <<<"${spec}"
    val="$(value_for "${key}")"
    upsert_var "${key}" "${masked}" "${protected}" "${val}"
  done
  log "done"
}

main "$@"
