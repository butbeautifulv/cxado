#!/usr/bin/env bash
# Phase 00 — verify Nexus + Kaniko bootstrap on P30 (read-only checks).
#
# Usage:
#   ./scripts/k8s/nexus-bootstrap-verify.sh
#   ./scripts/k8s/nexus-bootstrap-verify.sh --worker vm-01
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

NEXUS_API_BASE="${NEXUS_API_URL:-https://nexus.svo.aero:8443}"
NEXUS_API_BASE="${NEXUS_API_BASE%/}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
WORKER_HOST=""
SMOKE_IMAGE="${CXADO_CI_REGISTRY}/alpine:3.20.3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --worker) WORKER_HOST="${2:-vm-01}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[nexus-bootstrap-verify] %s\n' "$*"; }
pass() { printf 'OK   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; exit 1; }

remote() {
  ssh -p "${SSH_PORT}" -o ConnectTimeout=15 "${SSH_HOST}" "$@"
}

remote_sudo() {
  if [[ -n "${CXADO_OFFLINE_SUDO_PW:-}" ]]; then
    remote "printf '%s\n' '${CXADO_OFFLINE_SUDO_PW}' | sudo -S -p '' $*"
  else
    remote "sudo $*"
  fi
}

remote_ctr_pull() {
  local image="$1"
  if remote_sudo k3s ctr images ls 2>/dev/null | grep -Fq "${image}"; then
    return 0
  fi
  remote_sudo k3s ctr images pull "${image}"
}

log "00.1 — cxado-docker repo (kaniko-executor tag)"
if remote "curl -sk -u '${NEXUS_USER:-admin-SEC}:${NEXUS_PASSWORD}' \
  '${NEXUS_API_BASE}/service/rest/v1/repositories/${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}' \
  | grep -q '\"format\" : \"docker\"'"; then
  pass "Nexus repo ${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}"
else
  fail "Nexus repo missing — run ./scripts/k8s/nexus-cxado-docker-setup.sh"
fi

log "00.2 — kaniko-bootstrap secrets"
for ns in cxado-build cxado-app veil; do
  for secret in nexus-registry nexus-ca-cert; do
    if [[ "${ns}" == "cxado-app" && "${secret}" == "nexus-ca-cert" ]]; then
      continue
    fi
    if [[ "${ns}" == "veil" && "${secret}" == "nexus-ca-cert" ]]; then
      continue
    fi
    if remote "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl -n ${ns} get secret ${secret}" >/dev/null 2>&1; then
      pass "secret ${ns}/${secret}"
    else
      fail "missing ${ns}/${secret} — run ./scripts/k8s/kaniko-bootstrap.sh"
    fi
  done
done

log "00.3 — k3s registries.yaml on control plane"
if remote_sudo grep -q "${NEXUS_DOCKER_REGISTRY}" /etc/rancher/k3s/registries.yaml; then
  pass "registries.yaml on ${SSH_HOST}"
else
  fail "registries.yaml missing — run ansible-playbook deploy/ansible/k3s/playbooks/ci-images.yml"
fi

log "00.4 — smoke ctr pull ${SMOKE_IMAGE}"
if remote_ctr_pull "${SMOKE_IMAGE}" >/dev/null 2>&1; then
  pass "ctr pull on control plane"
else
  fail "ctr pull failed on control plane"
fi

if [[ -n "${WORKER_HOST}" ]]; then
  if ssh "${WORKER_HOST}" "sudo k3s ctr images pull '${SMOKE_IMAGE}'" >/dev/null 2>&1; then
    pass "ctr pull on worker ${WORKER_HOST}"
  else
    fail "ctr pull failed on worker ${WORKER_HOST}"
  fi
fi

VEIL_GOLANG_IMAGE="${CXADO_CI_REGISTRY}/golang-1.25-bookworm"
VEIL_DISTROLESS_IMAGE="${NEXUS_DOCKER_GROUP_REGISTRY}/distroless/static-debian12:nonroot"
VEIL_DISTROLESS_HOSTED="${CXADO_CI_REGISTRY}/distroless-static-debian12:nonroot"
log "00.7 — veil base images (golang hosted + distroless group proxy)"
if remote_ctr_pull "${VEIL_GOLANG_IMAGE}" >/dev/null 2>&1; then
  pass "ctr pull ${VEIL_GOLANG_IMAGE}"
else
  fail "ctr pull failed for ${VEIL_GOLANG_IMAGE} — run mirror-fabrica-ci-images.sh"
fi
if remote_ctr_pull "${VEIL_DISTROLESS_IMAGE}" >/dev/null 2>&1; then
  pass "ctr pull ${VEIL_DISTROLESS_IMAGE}"
elif remote_ctr_pull "${VEIL_DISTROLESS_HOSTED}" >/dev/null 2>&1; then
  pass "ctr pull ${VEIL_DISTROLESS_HOSTED} (hosted mirror; Kaniko uses group path at build)"
else
  fail "ctr pull failed for ${VEIL_DISTROLESS_IMAGE} — check Nexus group registry 8374 or mirror-fabrica-ci-images.sh"
fi

PLAYBOOKS_INDEX="/var/lib/veil/playbooks/docs/skills-index/cyber-skills.json"
PLAYBOOKS_CORPUS="/var/lib/veil/playbooks/corpus"
log "00.8 — playbooks hostPath on control-plane"
if remote "test -f '${PLAYBOOKS_INDEX}' && test -d '${PLAYBOOKS_CORPUS}'"; then
  pass "playbooks hostPath (${PLAYBOOKS_INDEX})"
else
  fail "missing playbooks hostPath — run ansible site.yml or scripts/veil/bootstrap-skills-index-hostpath.sh"
fi

log "00.9 — npm-proxy / go-proxy repos (egregore-ui bun install, veil go build)"
for REPO in "${NEXUS_NPM_REPO:-npm-proxy}" "${NEXUS_GO_REPO:-go-proxy}"; do
  if remote "code=\$(curl -sk -o /dev/null -w '%{http_code}' -u '${NEXUS_USER:-admin-SEC}:${NEXUS_PASSWORD}' \
    '${NEXUS_API_BASE}/service/rest/v1/repositories/${REPO}'); test \"\${code}\" = 200"; then
    pass "Nexus repo ${REPO}"
  else
    fail "Nexus repo ${REPO} missing — run ./scripts/k8s/nexus-npm-go-proxy-setup.sh"
  fi
done

log "bootstrap verify PASSED"
