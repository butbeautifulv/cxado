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

# key|masked|protected|type (env_var|file)
VARS=(
  "POSTGRES_PASSWORD|true|false|env_var"
  "REDIS_PASSWORD|true|false|env_var"
  "BUS_SIGNING_KEY|true|false|env_var"
  "CXADO_OFFLINE_SUDO_PW|true|false|env_var"
  "NEXUS_USER|true|false|env_var"
  "NEXUS_PASSWORD|true|false|env_var"
  "VM_01_PWD|true|false|env_var"
  "VM_02_PWD|true|false|env_var"
  "REGISTRY_HOST|false|false|env_var"
  "REGISTRY_REPOSITORY|false|false|env_var"
  "REGISTRY_BACKEND|false|false|env_var"
  "NEXUS_DOCKER_REGISTRY|false|false|env_var"
  "NEXUS_DOCKER_GROUP_REGISTRY|false|false|env_var"
  "NEXUS_CXADO_DOCKER_REPO|false|false|env_var"
  "NEXUS_PYPI_HOST|false|false|env_var"
  "NEXUS_PYPI_REPO|false|false|env_var"
  "GITLAB_RUNNER_TOKEN|true|false|env_var"
  "DEFECTDOJO_URL|false|false|env_var"
  "DEFECTDOJO_API_TOKEN|true|false|env_var"
  "DEFECTDOJO_PRODUCT_NAME|false|false|env_var"
  "DEFECTDOJO_ENGAGEMENT|false|false|env_var"
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
    NEXUS_DOCKER_GROUP_REGISTRY) echo "${NEXUS_DOCKER_GROUP_REGISTRY:-}" ;;
    NEXUS_CXADO_DOCKER_REPO) echo "${NEXUS_CXADO_DOCKER_REPO:-}" ;;
    NEXUS_PYPI_HOST) echo "${NEXUS_PYPI_HOST:-}" ;;
    NEXUS_PYPI_REPO) echo "${NEXUS_PYPI_REPO:-}" ;;
    GITLAB_RUNNER_TOKEN) echo "${GITLAB_RUNNER_TOKEN:-}" ;;
    DEFECTDOJO_URL) echo "${DEFECTDOJO_URL:-http://defectdojo.cxado-aspm.svc.cluster.local:8080}" ;;
    DEFECTDOJO_API_TOKEN) echo "${DEFECTDOJO_API_TOKEN:-${VM_01_DEFECTDOJO_API_TOKEN:-}}" ;;
    DEFECTDOJO_PRODUCT_NAME) echo "${DEFECTDOJO_PRODUCT_NAME:-egregore}" ;;
    DEFECTDOJO_ENGAGEMENT) echo "${DEFECTDOJO_ENGAGEMENT:-CI/CD}" ;;
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

api_body() { echo "$1" | sed '$d'; }

urlencode_key() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

is_maskable() {
  [[ "$1" =~ ^[A-Za-z0-9+/=]+$ ]]
}

fetch_defectdojo_token() {
  [[ -n "${VM_01_DEFECTDOJO_SU_PWD:-}" ]] || return 1
  USER="${VM_01_DEFECTDOJO_SU_NAME:-admin}" \
  PASS="${VM_01_DEFECTDOJO_SU_PWD}" \
  URL="${DEFECTDOJO_URL:-http://defectdojo.cxado-aspm.svc.cluster.local:8080}" \
  SSH_HOST="${SSH_HOST}" \
  python3 <<'PY'
import json
import os
import subprocess

body = json.dumps({"username": os.environ["USER"], "password": os.environ["PASS"]})
url = os.environ["URL"].rstrip("/") + "/api/v2/api-token-auth/"
proc = subprocess.run(
    ["ssh", os.environ["SSH_HOST"], f"curl -sk -X POST '{url}' -H 'Content-Type: application/json' -d @-"],
    input=body,
    capture_output=True,
    text=True,
    check=False,
)
if proc.returncode != 0 or not proc.stdout.strip():
    raise SystemExit(1)
print(json.loads(proc.stdout).get("token", ""))
PY
}

resolve_defectdojo_token() {
  if [[ -n "${DEFECTDOJO_API_TOKEN:-}" ]]; then
    echo "${DEFECTDOJO_API_TOKEN}"
    return 0
  fi
  if [[ -n "${VM_01_DEFECTDOJO_API_TOKEN:-}" ]]; then
    echo "${VM_01_DEFECTDOJO_API_TOKEN}"
    return 0
  fi
  fetch_defectdojo_token
}

upsert_var() {
  local key="$1" want_masked="$2" protected="$3" vtype="$4" value="$5"
  [[ -n "${value}" ]] || { log "skip ${key} (empty)"; return 0; }

  local masked="${want_masked}"
  if [[ "${want_masked}" == "true" ]] && ! is_maskable "${value}"; then
    log "WARN: ${key} not Base64-safe — stored unmasked (GitLab masked var rules)"
    masked="false"
  fi

  local body_create body_update code out
  body_create="$(KEY="${key}" VAL="${value}" MASKED="${masked}" PROTECTED="${protected}" VTYPE="${vtype}" python3 -c '
import json, os
print(json.dumps({
  "key": os.environ["KEY"],
  "value": os.environ["VAL"],
  "masked": os.environ["MASKED"] == "true",
  "protected": os.environ["PROTECTED"] == "true",
  "variable_type": os.environ["VTYPE"],
}))
')"
  body_update="$(KEY="${key}" VAL="${value}" MASKED="${masked}" PROTECTED="${protected}" python3 -c '
import json, os
print(json.dumps({
  "key": os.environ["KEY"],
  "value": os.environ["VAL"],
  "masked": os.environ["MASKED"] == "true",
  "protected": os.environ["PROTECTED"] == "true",
}))
')"

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] set ${key} type=${vtype} (masked=${masked})"
    return 0
  fi

  local enc_key
  enc_key="$(urlencode_key "${key}")"

  out="$(gitlab_api GET "/api/v4/projects/${PROJECT_ID}/variables/${enc_key}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  if [[ "${code}" == "200" ]]; then
    out="$(gitlab_api PUT "/api/v4/projects/${PROJECT_ID}/variables/${enc_key}" "${body_update}")"
    code="$(http_code "${out}")"
    if [[ "${code}" != "200" ]]; then
      log "ERROR: update ${key} HTTP ${code}: $(api_body "${out}")"
      if [[ "${masked}" == "true" ]]; then
        log "retry ${key} unmasked"
        body_update="$(KEY="${key}" VAL="${value}" MASKED="false" PROTECTED="${protected}" python3 -c '
import json, os
print(json.dumps({
  "key": os.environ["KEY"],
  "value": os.environ["VAL"],
  "masked": False,
  "protected": os.environ["PROTECTED"] == "true",
}))
')"
        out="$(gitlab_api PUT "/api/v4/projects/${PROJECT_ID}/variables/${enc_key}" "${body_update}")"
        code="$(http_code "${out}")"
      fi
    fi
    [[ "${code}" == "200" ]] || { log "ERROR: update ${key} HTTP ${code}: $(api_body "${out}")"; return 1; }
    log "updated ${key}"
  else
    out="$(gitlab_api POST "/api/v4/projects/${PROJECT_ID}/variables" "${body_create}")"
    code="$(http_code "${out}")"
    if [[ "${code}" != "201" ]]; then
      log "ERROR: create ${key} HTTP ${code}: $(api_body "${out}")"
      if [[ "${masked}" == "true" ]]; then
        log "retry create ${key} unmasked"
        body_create="$(KEY="${key}" VAL="${value}" MASKED="false" PROTECTED="${protected}" VTYPE="${vtype}" python3 -c '
import json, os
print(json.dumps({
  "key": os.environ["KEY"],
  "value": os.environ["VAL"],
  "masked": False,
  "protected": os.environ["PROTECTED"] == "true",
  "variable_type": os.environ["VTYPE"],
}))
')"
        out="$(gitlab_api POST "/api/v4/projects/${PROJECT_ID}/variables" "${body_create}")"
        code="$(http_code "${out}")"
      fi
    fi
    [[ "${code}" == "201" ]] || { log "ERROR: create ${key} HTTP ${code}: $(api_body "${out}")"; return 1; }
    log "created ${key}"
  fi
}

upsert_var_best_effort() {
  upsert_var "$@" || log "WARN: could not set $1 (continuing)"
}

main() {
  log "project ${GITLAB_URL}/av.popov/cxado (id ${PROJECT_ID})"
  local token
  token="$(resolve_defectdojo_token || true)"
  if [[ -n "${token}" ]]; then
    DEFECTDOJO_API_TOKEN="${token}"
    VM_01_DEFECTDOJO_API_TOKEN="${token}"
    log "DefectDojo API token resolved"
  else
    die "missing DEFECTDOJO_API_TOKEN — set in ${SECRETS} or VM_01_DEFECTDOJO_SU_* for auto-fetch"
  fi
  local spec key masked protected vtype val
  for spec in "${VARS[@]}"; do
    IFS='|' read -r key masked protected vtype <<<"${spec}"
    val="$(value_for "${key}")"
    upsert_var_best_effort "${key}" "${masked}" "${protected}" "${vtype}" "${val}"
  done

  local kc
  kc="$(kubeconfig_content)" || die "could not read kubeconfig for KUBECONFIG file variable"
  upsert_var "KUBECONFIG" "false" "false" "file" "${kc}"
  upsert_var "KUBE_INT_CONFIG" "false" "false" "file" "${kc}"

  if [[ "${DRY_RUN}" != true ]]; then
    local verify_out verify_code
    verify_out="$(gitlab_api GET "/api/v4/projects/${PROJECT_ID}/variables/$(urlencode_key "NEXUS_USER")" 2>/dev/null || true)"
    verify_code="$(http_code "${verify_out}")"
    if [[ "${verify_code}" == "200" ]]; then
      log "verified NEXUS_USER present in GitLab CI variables"
    else
      log "WARN: NEXUS_USER not readable via API (HTTP ${verify_code})"
    fi
  fi
  log "done"
}

main "$@"
