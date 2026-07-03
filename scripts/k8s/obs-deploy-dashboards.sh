#!/usr/bin/env bash
# Refresh Grafana dashboard ConfigMaps and restart Grafana on offline k3s.
#
# Usage:
#   ./scripts/k8s/obs-deploy-dashboards.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS="${CXADO_OBS_NS}"
KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
RSYNC_SSH="ssh -p ${SSH_PORT}"
GRAFANA_URL="${GRAFANA_URL:-http://${CXADO_NODE_IP}:30002}"

DASHBOARD_UIDS=(
  cxado-overview
  egregore-cys-agi
  egregore-observability
  egregore-sgr
  veil-graph
  veil-observability
  cxado-infra-host
  cxado-infra-k3s
  vllm-monitoring-exec
)

log() { printf '[obs-dashboards] %s\n' "$*"; }

decode_secret() {
  local ns="$1" name="$2" key="$3"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" \
    "${KCTL} get secret -n ${ns} ${name} -o jsonpath='{.data.${key}}'" \
    | python3 -c "import sys,base64; print(base64.b64decode(sys.stdin.read()).decode())"
}

delete_provisioned_dashboards() {
  local admin_pw="$1"
  log "deleting stale Grafana dashboards (force reprovision)"
  for uid in "${DASHBOARD_UIDS[@]}"; do
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "curl -fsS -u admin:${admin_pw} -X DELETE '${GRAFANA_URL}/api/dashboards/uid/${uid}'" \
      >/dev/null 2>&1 || true
  done
  ssh -p "${SSH_PORT}" "${SSH_HOST}" \
    "${KCTL} -n ${NS} rollout restart deploy/grafana"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" \
    "${KCTL} -n ${NS} rollout status deploy/grafana --timeout=120s"
}

log "target ${SSH_HOST}:${SSH_PORT} namespace ${NS}"

if [[ -x "${ROOT}/scripts/k8s/validate-grafana-promql.sh" ]]; then
  log "validating PromQL locally"
  "${ROOT}/scripts/k8s/validate-grafana-promql.sh" || {
    log "PromQL validation failed — fix dashboards before deploy"
    exit 1
  }
fi

ssh -p "${SSH_PORT}" "${SSH_HOST}" 'bash -lc "rm -rf /tmp/cxado-obs-bundle && mkdir -p /tmp/cxado-obs-bundle/k8s /tmp/cxado-obs-bundle/observability"'
rsync -a -e "${RSYNC_SSH}" "${ROOT}/deploy/k8s/obs-offline/prometheus-k3s.yml" "${SSH_HOST}:/tmp/cxado-obs-bundle/k8s/"
rsync -a -e "${RSYNC_SSH}" "${ROOT}/deploy/observability/" "${SSH_HOST}:/tmp/cxado-obs-bundle/observability/"
ssh -p "${SSH_PORT}" "${SSH_HOST}" 'bash -lc "cat >/tmp/obs-create-configmaps.sh"' < "${ROOT}/scripts/k8s/obs-create-configmaps.sh"
ssh -p "${SSH_PORT}" "${SSH_HOST}" 'bash -lc "chmod +x /tmp/obs-create-configmaps.sh"'
ssh -p "${SSH_PORT}" "${SSH_HOST}" "CXADO_OBS_SRC=/tmp/cxado-obs-bundle KUBECONFIG=/home/bbv/.kube/config KUBECTL='k3s kubectl' /tmp/obs-create-configmaps.sh"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} apply -f -" < "${ROOT}/deploy/k8s/obs-offline/20-grafana.yaml"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n ${NS} rollout restart deploy/prometheus deploy/grafana"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n ${NS} rollout status deploy/prometheus --timeout=120s"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n ${NS} rollout status deploy/grafana --timeout=120s"

GRAFANA_ADMIN="$(decode_secret "${NS}" grafana-auth admin_password)"
delete_provisioned_dashboards "${GRAFANA_ADMIN}"

log "done — Grafana: https://${CXADO_NODE_IP}:30002"
