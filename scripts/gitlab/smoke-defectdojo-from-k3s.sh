#!/usr/bin/env bash
# Smoke: CI pods on P30 k3s can reach DefectDojo API on VM_01.
#
# Usage:
#   ./scripts/gitlab/smoke-defectdojo-from-k3s.sh
#   ./scripts/gitlab/smoke-defectdojo-from-k3s.sh --ssh bbv-p30-wifi
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
DD_URL="${DEFECTDOJO_URL:-http://10.20.16.195:8080}"
DD_TOKEN="${DEFECTDOJO_API_TOKEN:-${VM_01_DEFECTDOJO_API_TOKEN:-}}"
NS="${CXADO_CI_NS:-cxado-ci}"

log() { printf '[smoke-defectdojo-k3s] %s\n' "$*"; }
die() { echo "[smoke-defectdojo-k3s] ERROR: $*" >&2; exit 2; }

[[ -n "${DD_TOKEN}" ]] || die "missing DEFECTDOJO_API_TOKEN in ${SECRETS}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_HOST="${2:-bbv-p30-wifi}"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

log "curl ${DD_URL}/api/v2/users/?limit=1 from pod in ${NS}"
ssh "${SSH_HOST}" "export KUBECONFIG=/home/bbv/.kube/config; \
  k3s kubectl -n '${NS}' run defectdojo-smoke --rm -i --restart=Never \
    --image='${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}/${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}/alpine:3.20.3' \
    --command -- wget -qO- --header='Authorization: Token ${DD_TOKEN}' '${DD_URL%/}/api/v2/users/?limit=1'"

log "ok — DefectDojo reachable from k3s"
