#!/usr/bin/env bash
# Create npm-proxy and go-proxy repos in Nexus — closes the last direct-internet
# dependency in Kaniko builds (egregore-ui `bun install`, veil-api/mcp `go build`).
#
# Both formats are native to Nexus Repository OSS 3.20+ (npm/proxy, go/proxy) — no
# license/plugin needed. Served on the same web port as PyPI (NEXUS_PYPI_HOST),
# so the CA trust that already works for `uv sync` covers these too.
#
# Usage:
#   ./scripts/k8s/nexus-npm-go-proxy-setup.sh
#   ./scripts/k8s/nexus-npm-go-proxy-setup.sh --ssh bbv-p30-wifi
#   ./scripts/k8s/nexus-npm-go-proxy-setup.sh --ssh bbv-p30-wifi --npm-only
#   ./scripts/k8s/nexus-npm-go-proxy-setup.sh --ssh bbv-p30-wifi --go-only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=deploy/registry.defaults.env
[[ -f "${ROOT}/deploy/registry.defaults.env" ]] && source "${ROOT}/deploy/registry.defaults.env"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

NEXUS_API_URL="${NEXUS_API_URL:-https://nexus.svo.aero:8443}"
NEXUS_USER="${NEXUS_USER:-admin-SEC}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-}"
NEXUS_NPM_REPO="${NEXUS_NPM_REPO:-npm-proxy}"
NEXUS_GO_REPO="${NEXUS_GO_REPO:-go-proxy}"
NPM_REMOTE_URL="${NPM_REMOTE_URL:-https://registry.npmjs.org}"
GO_REMOTE_URL="${GO_REMOTE_URL:-https://proxy.golang.org}"

SSH_VIA=""
RUN_NPM=1
RUN_GO=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_VIA="${2:-bbv-p30-wifi}"; shift 2 ;;
    --npm-only) RUN_NPM=1; RUN_GO=0; shift ;;
    --go-only) RUN_NPM=0; RUN_GO=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[nexus-npm-go-proxy] %s\n' "$*"; }

if [[ -z "${NEXUS_PASSWORD}" ]]; then
  echo "missing NEXUS_PASSWORD in ${SECRETS}" >&2
  exit 2
fi

nexus_curl() {
  local method="$1" path="$2" body="${3:-}"
  local url="${NEXUS_API_URL%/}${path}"
  if [[ -n "${SSH_VIA}" ]]; then
    if [[ -n "${body}" ]]; then
      ssh "${SSH_VIA}" "curl -sk -u '${NEXUS_USER}:${NEXUS_PASSWORD}' -X '${method}' \
        -H 'Content-Type: application/json' -d $(printf '%q' "${body}") '${url}' -w '\nHTTP:%{http_code}\n'"
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

ensure_npm_proxy() {
  local out code
  out="$(nexus_curl GET "/service/rest/v1/repositories/${NEXUS_NPM_REPO}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  if [[ "${code}" == "200" ]]; then
    log "repo exists: ${NEXUS_NPM_REPO}"
    return 0
  fi
  log "create npm proxy repo: ${NEXUS_NPM_REPO} -> ${NPM_REMOTE_URL}"
  local body
  body="$(cat <<EOF
{
  "name": "${NEXUS_NPM_REPO}",
  "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
  "proxy": {"remoteUrl": "${NPM_REMOTE_URL}", "contentMaxAge": 1440, "metadataMaxAge": 1440},
  "negativeCache": {"enabled": true, "timeToLive": 1440},
  "httpClient": {"blocked": false, "autoBlock": true}
}
EOF
)"
  out="$(nexus_curl POST "/service/rest/v1/repositories/npm/proxy" "${body}")"
  code="$(http_code "${out}")"
  if [[ "${code}" != "201" && "${code}" != "200" ]]; then
    echo "${out}" >&2
    exit 1
  fi
}

ensure_go_proxy() {
  local out code
  out="$(nexus_curl GET "/service/rest/v1/repositories/${NEXUS_GO_REPO}" 2>/dev/null || true)"
  code="$(http_code "${out}")"
  if [[ "${code}" == "200" ]]; then
    log "repo exists: ${NEXUS_GO_REPO}"
    return 0
  fi
  log "create go proxy repo: ${NEXUS_GO_REPO} -> ${GO_REMOTE_URL}"
  local body
  body="$(cat <<EOF
{
  "name": "${NEXUS_GO_REPO}",
  "online": true,
  "storage": {"blobStoreName": "default", "strictContentTypeValidation": true},
  "proxy": {"remoteUrl": "${GO_REMOTE_URL}", "contentMaxAge": 1440, "metadataMaxAge": 1440},
  "negativeCache": {"enabled": true, "timeToLive": 1440},
  "httpClient": {"blocked": false, "autoBlock": true}
}
EOF
)"
  out="$(nexus_curl POST "/service/rest/v1/repositories/go/proxy" "${body}")"
  code="$(http_code "${out}")"
  if [[ "${code}" != "201" && "${code}" != "200" ]]; then
    if [[ "${code}" == "400" ]]; then
      echo "${out}" >&2
      echo "hint: Go proxy format may need enabling — Nexus Admin > System > Capabilities > 'Go Bridge' or 'Go: Proxy Repository' capability must be present in this Nexus edition." >&2
    fi
    exit 1
  fi
}

[[ "${RUN_NPM}" == "1" ]] && ensure_npm_proxy
[[ "${RUN_GO}" == "1" ]] && ensure_go_proxy
log "done — npm: ${NEXUS_API_URL%/}/repository/${NEXUS_NPM_REPO}/, go: ${NEXUS_API_URL%/}/repository/${NEXUS_GO_REPO}/"
