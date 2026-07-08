#!/usr/bin/env bash
# Create/update Nexus raw repos for k3s airgap (add-only; never deletes existing repos).
#
# Fixes k3s-releases-proxy per GitHub releases proxy pattern:
#   https://sam.gleske.net/blog/engineering/2023/10/06/nexus-proxy-github-releases.html
#   remoteUrl=https://github.com + routing rule + path prefix in downloads.
#
# Repos (create or repair):
#   k3s-releases-proxy  — GitHub releases (k3s-io/k3s/releases/download/...)
#   k3s-releases-hosted — optional manual cache fallback
#   helm-get-proxy      — get.helm.sh
#
# Usage:
#   ./scripts/k8s/nexus-k3s-repos-setup.sh
#   ./scripts/k8s/nexus-k3s-repos-setup.sh --ssh bbv-p30-wifi
#   ./scripts/k8s/nexus-k3s-repos-setup.sh --ssh bbv-p30-wifi --test
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh" 2>/dev/null || true

SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

NEXUS_API_URL="${NEXUS_API_URL:-https://nexus.svo.aero:8443}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
ROUTING_RULE_NAME="${NEXUS_GITHUB_ROUTING_RULE:-GitHubReleases}"
K3S_PROXY_REPO="${NEXUS_K3S_PROXY_REPO:-k3s-releases-proxy}"
K3S_GET_PROXY_REPO="${NEXUS_K3S_GET_PROXY_REPO:-k3s-get-proxy}"
K3S_HOSTED_REPO="${NEXUS_K3S_HOSTED_REPO:-k3s-releases-hosted}"
HELM_PROXY_REPO="${NEXUS_HELM_PROXY_REPO:-helm-get-proxy}"
K3S_VERSION="${K3S_VERSION:-v1.35.6+k3s1}"

SSH_VIA=""
RUN_TEST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_VIA="${2:-bbv-p30-wifi}"; shift 2 ;;
    --test) RUN_TEST=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[nexus-k3s-repos] %s\n' "$*"; }

if [[ -z "${NEXUS_PASSWORD}" ]]; then
  echo "missing NEXUS_PASSWORD in ${SECRETS}" >&2
  exit 2
fi

nexus_curl() {
  local method="$1" path="$2" body="${3:-}"
  local url="${NEXUS_API_URL%/}${path}"
  if [[ -n "${SSH_VIA}" ]]; then
    local body_arg=""
    if [[ -n "${body}" ]]; then
      body_arg="$(printf '%q' "${body}")"
      ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' -X '${method}' \
        -H 'Content-Type: application/json' \
        -d ${body_arg} \
        '${url}' -w '\nHTTP:%{http_code}\n'"
    else
      ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' -X '${method}' \
        '${url}' -w '\nHTTP:%{http_code}\n'"
    fi
  else
    curl -sk -u "${NEXUS_USER}:${NEXUS_PASSWORD}" -X "${method}" \
      -H "Content-Type: application/json" \
      ${body:+-d "${body}"} \
      "${url}" -w "\nHTTP:%{http_code}\n"
  fi
}

http_code() { echo "$1" | tail -1 | sed 's/HTTP://'; }

repo_exists() {
  local name="$1"
  local out code
  out="$(nexus_curl GET "/service/rest/v1/repositories/${name}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  [[ "${code}" == "200" ]]
}

routing_rule_exists() {
  local out code
  out="$(nexus_curl GET "/service/rest/v1/routing-rules/${ROUTING_RULE_NAME}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  [[ "${code}" == "200" ]]
}

ensure_github_routing_rule() {
  if routing_rule_exists; then
    log "routing rule exists: ${ROUTING_RULE_NAME}"
    return 0
  fi
  log "create routing rule: ${ROUTING_RULE_NAME}"
  local body
  body="$(cat <<EOF
{
  "name": "${ROUTING_RULE_NAME}",
  "description": "GitHub releases and source archives (corp cache)",
  "mode": "ALLOW",
  "matchers": [
    "/[^/]+/[^/]+/releases/download/[^/]+/.+"
  ]
}
EOF
)"
  local out code
  out="$(nexus_curl POST "/service/rest/v1/routing-rules" "${body}")"
  code="$(http_code "${out}")"
  if [[ "${code}" != "201" && "${code}" != "200" && "${code}" != "204" ]]; then
    echo "${out}" >&2
    echo "failed to create routing rule HTTP ${code}" >&2
    exit 1
  fi
}

raw_proxy_body() {
  local name="$1" remote_url="$2" routing_rule="${3:-}"
  local routing_json="null"
  if [[ -n "${routing_rule}" ]]; then
    routing_json="\"${routing_rule}\""
  fi
  cat <<EOF
{
  "name": "${name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": false
  },
  "cleanup": null,
  "proxy": {
    "remoteUrl": "${remote_url}",
    "contentMaxAge": -1,
    "metadataMaxAge": 30
  },
  "negativeCache": {
    "enabled": true,
    "timeToLive": 5
  },
  "httpClient": {
    "blocked": false,
    "autoBlock": true,
    "connection": {
      "retries": 3,
      "timeout": 120,
      "enableCircularRedirects": true,
      "enableCookies": true
    }
  },
  "routingRule": ${routing_json},
  "raw": {
    "contentDisposition": "ATTACHMENT"
  }
}
EOF
}

create_or_update_raw_proxy() {
  local name="$1" remote_url="$2" routing_rule="${3:-}"
  local body
  body="$(raw_proxy_body "${name}" "${remote_url}" "${routing_rule}")"
  if repo_exists "${name}"; then
    log "update raw proxy: ${name} -> ${remote_url}${routing_rule:+ (routing=${routing_rule})}"
    local out code
    out="$(nexus_curl PUT "/service/rest/v1/repositories/raw/proxy/${name}" "${body}")"
    code="$(http_code "${out}")"
    if [[ "${code}" != "204" && "${code}" != "200" ]]; then
      echo "${out}" >&2
      echo "failed to update ${name} HTTP ${code}" >&2
      exit 1
    fi
  else
    log "create raw proxy: ${name} -> ${remote_url}${routing_rule:+ (routing=${routing_rule})}"
    local out code
    out="$(nexus_curl POST "/service/rest/v1/repositories/raw/proxy" "${body}")"
    code="$(http_code "${out}")"
    if [[ "${code}" != "201" && "${code}" != "200" && "${code}" != "204" ]]; then
      echo "${out}" >&2
      echo "failed to create ${name} HTTP ${code}" >&2
      exit 1
    fi
  fi
}

create_raw_hosted() {
  local name="$1"
  if repo_exists "${name}"; then
    log "skip exists: ${name}"
    return 0
  fi
  log "create raw hosted: ${name}"
  local body
  body="$(cat <<EOF
{
  "name": "${name}",
  "online": true,
  "storage": {
    "blobStoreName": "default",
    "strictContentTypeValidation": false,
    "writePolicy": "ALLOW"
  },
  "raw": {
    "contentDisposition": "ATTACHMENT"
  }
}
EOF
)"
  nexus_curl POST "/service/rest/v1/repositories/raw/hosted" "${body}"
}

invalidate_negative_cache() {
  local name="$1"
  log "invalidate negative cache: ${name}"
  nexus_curl POST "/service/rest/v1/repositories/${name}/invalidate-cache" "" || true
}

urlencode_version() {
  # GitHub release tags use '+' (e.g. v1.35.6+k3s1); encode for HTTP paths.
  printf '%s' "$1" | sed 's/+/%2B/g'
}

test_k3s_proxy() {
  local ver_enc
  ver_enc="$(urlencode_version "${K3S_VERSION}")"
  local rel_base="${NEXUS_API_URL%/}/repository/${K3S_PROXY_REPO}/k3s-io/k3s/releases/download/${ver_enc}"
  local get_base="${NEXUS_API_URL%/}/repository/${K3S_GET_PROXY_REPO}"
  local helm_url="${NEXUS_API_URL%/}/repository/${HELM_PROXY_REPO}/helm-v4.1.0-linux-amd64.tar.gz"
  local tests=(
    "${get_base}/|install|text"
    "${rel_base}/k3s|k3s|elf"
    "${rel_base}/k3s-airgap-images-amd64.tar|images|tar"
    "${helm_url}|helm|gzip"
  )
  log "smoke test k3s/helm proxies version=${K3S_VERSION}"
  for spec in "${tests[@]}"; do
    local url="${spec%%|*}"
    local rest="${spec#*|}"
    local label="${rest%%|*}"
    local expect="${rest##*|}"
    log "  GET ${label} ..."
    local code type
    if [[ -n "${SSH_VIA}" ]]; then
      ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' \
        'https://nexus.svo.aero:8443/service/rest/v1/repositories/${K3S_PROXY_REPO}/invalidate-cache' \
        -X POST >/dev/null 2>&1 || true"
      code="$(ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' -o /tmp/nexus-test-${label} -w '%{http_code}' '${url}'")"
      type="$(ssh "${SSH_VIA}" "file -b /tmp/nexus-test-${label} 2>/dev/null || echo unknown")"
      ssh "${SSH_VIA}" "rm -f /tmp/nexus-test-${label}" >/dev/null 2>&1 || true
    else
      local tmp
      tmp="$(mktemp)"
      code="$(curl -sk -u "${NEXUS_USER}:${NEXUS_PASSWORD}" -o "${tmp}" -w '%{http_code}' "${url}")"
      type="$(file -b "${tmp}" 2>/dev/null || echo unknown)"
      rm -f "${tmp}"
    fi
    if [[ "${code}" != "200" ]]; then
      log "  FAIL ${label}: HTTP ${code}"
      return 1
    fi
    case "${expect}" in
      elf) [[ "${type}" == *"ELF"* ]] || { log "  FAIL ${label}: expected ELF, got ${type}"; return 1; } ;;
      text) [[ "${type}" == *"ASCII"* || "${type}" == *"text"* || "${type}" == *"shell"* ]] \
        || { log "  FAIL ${label}: expected script, got ${type}"; return 1; } ;;
      tar) [[ "${type}" == *"tar archive"* || "${type}" == *"POSIX"* ]] \
        || { log "  FAIL ${label}: expected tar, got ${type}"; return 1; } ;;
      gzip) [[ "${type}" == *"gzip"* ]] || { log "  FAIL ${label}: expected gzip, got ${type}"; return 1; } ;;
    esac
    log "  OK ${label} (${type})"
  done
}

ensure_github_routing_rule
create_or_update_raw_proxy "${K3S_PROXY_REPO}" "https://github.com" "${ROUTING_RULE_NAME}"
create_raw_hosted "${K3S_HOSTED_REPO}"
create_or_update_raw_proxy "${K3S_GET_PROXY_REPO}" "https://get.k3s.io"
create_or_update_raw_proxy "${HELM_PROXY_REPO}" "https://get.helm.sh"
invalidate_negative_cache "${K3S_PROXY_REPO}"
invalidate_negative_cache "${K3S_GET_PROXY_REPO}"
invalidate_negative_cache "${HELM_PROXY_REPO}"

log "done — download URLs:"
log "  helm:   ${NEXUS_API_URL}/repository/${HELM_PROXY_REPO}/helm-..."
log "  k3s:    ${NEXUS_API_URL}/repository/${K3S_PROXY_REPO}/k3s-io/k3s/releases/download/<version>/..."
log "  install:${NEXUS_API_URL}/repository/${K3S_GET_PROXY_REPO}/"
log "  hosted: ${NEXUS_API_URL}/repository/${K3S_HOSTED_REPO}/<version>/... (manual fallback)"

if [[ "${RUN_TEST}" == true ]]; then
  test_k3s_proxy
  log "smoke test passed"
fi
