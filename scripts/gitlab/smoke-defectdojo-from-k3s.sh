#!/usr/bin/env bash
# Smoke: CI pods on P30 k3s can reach in-cluster DefectDojo API.
#
# Usage:
#   ./scripts/gitlab/smoke-defectdojo-from-k3s.sh
#   ./scripts/gitlab/smoke-defectdojo-from-k3s.sh --ssh bbv-p30-wifi
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
DD_URL="${DEFECTDOJO_URL:-http://defectdojo.cxado-aspm.svc.cluster.local:8080}"
DD_TOKEN="${DEFECTDOJO_API_TOKEN:-}"
DD_ADMIN_USER="${DD_ADMIN_USER:-${VM_01_DEFECTDOJO_SU_NAME:-admin}}"
DD_ADMIN_PASS="${DD_ADMIN_PASSWORD:-${VM_01_DEFECTDOJO_SU_PWD:-}}"
NS="${CXADO_CI_NS:-cxado-ci}"

log() { printf '[smoke-defectdojo-k3s] %s\n' "$*"; }
die() { echo "[smoke-defectdojo-k3s] ERROR: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh) SSH_HOST="${2:-bbv-p30-wifi}"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

fetch_token_remote() {
  [[ -n "${DD_ADMIN_PASS}" ]] || return 1
  ssh "${SSH_HOST}" "curl -sk -X POST '${DD_URL%/}/api/v2/api-token-auth/' \
    -H 'Content-Type: application/json' \
    -d '{\"username\":\"${DD_ADMIN_USER}\",\"password\":\"${DD_ADMIN_PASS}\"}'" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))'
}

if [[ -z "${DD_TOKEN}" ]]; then
  DD_TOKEN="$(fetch_token_remote 2>/dev/null || true)"
fi

[[ -n "${DD_TOKEN}" ]] || die "missing DEFECTDOJO_API_TOKEN — run k3s-deploy-defectdojo.sh or set in ${SECRETS}"

log "GET ${DD_URL}/api/v2/users/?limit=1 from pod in ${NS}"
if ! ssh "${SSH_HOST}" "export KUBECONFIG=/home/bbv/.kube/config; \
  k3s kubectl -n '${NS}' run defectdojo-smoke --rm -i --restart=Never \
    --image='${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}/${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}/alpine:3.20.3' \
    --overrides='{\"spec\":{\"nodeSelector\":{\"node-role.kubernetes.io/control-plane\":\"true\"},\"tolerations\":[{\"key\":\"node-role.kubernetes.io/control-plane\",\"operator\":\"Exists\",\"effect\":\"NoSchedule\"}],\"imagePullSecrets\":[{\"name\":\"nexus-registry\"}],\"containers\":[{\"name\":\"defectdojo-smoke\",\"image\":\"${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}/${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}/alpine:3.20.3\",\"command\":[\"wget\",\"-qO-\",\"--header=Authorization: Token ${DD_TOKEN}\",\"${DD_URL%/}/api/v2/users/?limit=1\"],\"resources\":{\"requests\":{\"cpu\":\"10m\",\"memory\":\"32Mi\"},\"limits\":{\"cpu\":\"50m\",\"memory\":\"64Mi\"}}}]}}'"; then
  die "pod cannot reach ${DD_URL} — check defectdojo.cxado-aspm rollout (./scripts/k8s/k3s-deploy-defectdojo.sh)"
fi

log "ok — DefectDojo reachable from k3s"
