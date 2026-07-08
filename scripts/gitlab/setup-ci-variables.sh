#!/usr/bin/env bash
# Seed GitLab CI/CD variables for cxado → k3s pipeline (via P30 API hop).
#
# Usage:
#   ./scripts/gitlab/setup-ci-variables.sh
#   ./scripts/gitlab/setup-ci-variables.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=deploy/registry.defaults.env
[[ -f "${ROOT}/deploy/registry.defaults.env" ]] && source "${ROOT}/deploy/registry.defaults.env"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
PROJECT_ID="${GITLAB_PROJECT_ID:-1938}"
PAT="${GITLAB_PAT_RUNNER:-}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
DRY_RUN=false
KUBECONFIG_SRC="${CXADO_KUBECONFIG_SRC:-}"

log() { printf '[setup-ci-variables] %s\n' "$*"; }
die() { echo "[setup-ci-variables] ERROR: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -n "${PAT}" ]] || die "missing GITLAB_PAT_RUNNER in ${SECRETS}"

# key|masked|protected|type (env|file)
VARS=(
  "POSTGRES_PASSWORD|true|false|env"
  "REDIS_PASSWORD|true|false|env"
  "BUS_SIGNING_KEY|true|false|env"
  "CXADO_OFFLINE_SUDO_PW|true|false|env"
  "NEXUS_USER|true|false|env"
  "NEXUS_PASSWORD|true|false|env"
  "VM_01_PWD|true|false|env"
  "VM_02_PWD|true|false|env"
  "REGISTRY_HOST|false|false|env"
  "REGISTRY_REPOSITORY|false|false|env"
  "REGISTRY_BACKEND|false|false|env"
  "NEXUS_DOCKER_REGISTRY|false|false|env"
  "NEXUS_CXADO_DOCKER_REPO|false|false|env"
  "NEXUS_PYPI_HOST|false|false|env"
  "NEXUS_PYPI_REPO|false|false|env"
  "GITLAB_RUNNER_TOKEN|true|false|env"
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
    REGISTRY_HOST) echo "${REGISTRY_HOST:-${NEXUS_DOCKER_REGISTRY:-}}" ;;
    REGISTRY_REPOSITORY) echo "${REGISTRY_REPOSITORY:-${NEXUS_CXADO_DOCKER_REPO:-}}" ;;
    REGISTRY_BACKEND) echo "${REGISTRY_BACKEND:-nexus}" ;;
    NEXUS_DOCKER_REGISTRY) echo "${NEXUS_DOCKER_REGISTRY:-}" ;;
    NEXUS_CXADO_DOCKER_REPO) echo "${NEXUS_CXADO_DOCKER_REPO:-}" ;;
    NEXUS_PYPI_HOST) echo "${NEXUS_PYPI_HOST:-}" ;;
    NEXUS_PYPI_REPO) echo "${NEXUS_PYPI_REPO:-}" ;;
    GITLAB_RUNNER_TOKEN) echo "${GITLAB_RUNNER_TOKEN:-}" ;;
    *) return 1 ;;
  esac
}

kubeconfig_content() {
  if [[ -n "${KUBECONFIG_SRC}" && -f "${KUBECONFIG_SRC}" ]]; then
    cat "${KUBECONFIG_SRC}"
    return 0
  fi
  if [[ -f "${ROOT}/deploy/.secrets/kubeconfig" ]]; then
    cat "${ROOT}/deploy/.secrets/kubeconfig"
    return 0
  fi
  ssh "${SSH_HOST}" "cat /home/bbv/.kube/config 2>/dev/null || cat /etc/rancher/k3s/k3s.yaml 2>/dev/null"
}

gitlab_api() {
  local method="$1" path="$2" body="${3:-}"
  local url="${GITLAB_URL%/}${path}"
  if [[ -n "${body}" ]]; then
    local remote_body="/tmp/cxado-gl-var-$$.json"
    printf '%s' "${body}" | ssh "${SSH_HOST}" "cat > '${remote_body}'"
    ssh "${SSH_HOST}" "curl -sk --request '${method}' '${url}' \
      --header 'PRIVATE-TOKEN: ${PAT}' --header 'Content-Type: application/json' \
      --data @'${remote_body}' -w '\nHTTP:%{http_code}\n'; rm -f '${remote_body}'"
  else
    ssh "${SSH_HOST}" "curl -sk --request '${method}' '${url}' \
      --header 'PRIVATE-TOKEN: ${PAT}' -w '\nHTTP:%{http_code}\n'"
  fi
}

http_code() { echo "$1" | tail -1 | sed 's/HTTP://'; }

is_maskable() {
  [[ "$1" =~ ^[A-Za-z0-9+/=]+$ ]]
}

upsert_var() {
  local key="$1" want_masked="$2" protected="$3" vtype="$4" value="$5"
  [[ -n "${value}" ]] || { log "skip ${key} (empty)"; return 0; }

  local masked="${want_masked}"
  if [[ "${want_masked}" == "true" ]] && ! is_maskable "${value}"; then
    log "WARN: ${key} not Base64-safe — stored unmasked (GitLab masked var rules)"
    masked="false"
  fi

  local body code out
  body="$(KEY="${key}" VAL="${value}" MASKED="${masked}" PROTECTED="${protected}" VTYPE="${vtype}" python3 -c '
import json, os
print(json.dumps({
  "key": os.environ["KEY"],
  "value": os.environ["VAL"],
  "masked": os.environ["MASKED"] == "true",
  "protected": os.environ["PROTECTED"] == "true",
  "variable_type": os.environ["VTYPE"],
}))
')"

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] set ${key} type=${vtype} (masked=${masked})"
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
  local spec key masked protected vtype val
  for spec in "${VARS[@]}"; do
    IFS='|' read -r key masked protected vtype <<<"${spec}"
    val="$(value_for "${key}")"
    upsert_var "${key}" "${masked}" "${protected}" "${vtype}" "${val}"
  done

  local kc
  kc="$(kubeconfig_content)" || die "could not read kubeconfig for KUBECONFIG file variable"
  upsert_var "KUBECONFIG" "false" "false" "file" "${kc}"
  upsert_var "KUBE_INT_CONFIG" "false" "false" "file" "${kc}"
  log "done"
}

main "$@"
