#!/usr/bin/env bash
# Deploy Veil graph plane (+ optional workers overlay) onto k3s offline.
#
# Usage:
#   VEIL_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-deploy-veil-offline.sh
#   VEIL_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-deploy-veil-offline.sh --with-workers-obs
#
# Remote (SSH hop to target node):
#   VEIL_OFFLINE_SSH_HOST=bbv@10.8.184.22 VEIL_OFFLINE_SSH_PORT=22012 \
#     VEIL_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-deploy-veil-offline.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${VEIL_OFFLINE_TAG:-${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}}"
SSH_HOST="${VEIL_OFFLINE_SSH_HOST:-${CXADO_OFFLINE_SSH_HOST}}"
SSH_PORT="${VEIL_OFFLINE_SSH_PORT:-${CXADO_OFFLINE_SSH_PORT}}"
WITH_WORKERS_OBS=0
SMOKE_OBS=1
CXADO_VEIL_PROFILE="${CXADO_VEIL_PROFILE:-graph-only}"

for arg in "$@"; do
  case "$arg" in
    --with-workers-obs) WITH_WORKERS_OBS=1; CXADO_VEIL_PROFILE=workers-obs ;;
    --no-smoke) SMOKE_OBS=0 ;;
  esac
done

log() { printf '[veil-deploy] %s\n' "$*"; }

kubectl_cmd() {
  if [[ -n "$SSH_HOST" ]]; then
    # shellcheck disable=SC2029
    ssh -p "$SSH_PORT" "$SSH_HOST" \
      "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
  else
    kubectl "$@"
  fi
}

helm_cmd() {
  if [[ -n "$SSH_HOST" ]]; then
    # shellcheck disable=SC2029
    ssh -p "$SSH_PORT" "$SSH_HOST" \
      "KUBECONFIG=/home/bbv/.kube/config helm $(printf '%q ' "$@")"
  else
    helm "$@"
  fi
}

apply_file() {
  local f="$1"
  if [[ -n "$SSH_HOST" ]]; then
    ssh -p "$SSH_PORT" "$SSH_HOST" "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl apply -f -" <"$f"
  else
    kubectl apply -f "$f"
  fi
}

refresh_prometheus_profile() {
  log "prometheus profile=${CXADO_VEIL_PROFILE}"
  if [[ -n "$SSH_HOST" ]]; then
    rsync -a -e "ssh -p ${SSH_PORT}" \
      "${ROOT}/deploy/k8s/obs-offline/" \
      "${SSH_HOST}:/tmp/cxado-obs-k8s/"
    rsync -a -e "ssh -p ${SSH_PORT}" \
      "${ROOT}/deploy/observability/" \
      "${SSH_HOST}:/tmp/cxado-obs-bundle/observability/"
    ssh -p "$SSH_PORT" "$SSH_HOST" \
      "CXADO_OBS_SRC=/tmp/cxado-obs-bundle CXADO_VEIL_PROFILE='${CXADO_VEIL_PROFILE}' \
       K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config \
       bash -s" < "${ROOT}/scripts/k8s/obs-create-configmaps.sh"
    kubectl_cmd -n cxado-obs rollout restart deploy/prometheus
    kubectl_cmd -n cxado-obs rollout status deploy/prometheus --timeout=180s
  else
    CXADO_VEIL_PROFILE="${CXADO_VEIL_PROFILE}" "${ROOT}/scripts/k8s/obs-create-configmaps.sh"
    kubectl_cmd -n cxado-obs rollout restart deploy/prometheus
    kubectl_cmd -n cxado-obs rollout status deploy/prometheus --timeout=180s
  fi
}

copy_and_sed_values() {
  local dest="/tmp/values-veil-offline.yaml"
  sed "s/__VEIL_OFFLINE_TAG__/${TAG}/g" "${ROOT}/deploy/k8s/veil-offline/values-graph-only.yaml" >"${ROOT}/.tmp-values-veil-offline.yaml"
  if [[ -n "$SSH_HOST" ]]; then
    scp -P "$SSH_PORT" "${ROOT}/.tmp-values-veil-offline.yaml" "${SSH_HOST}:${dest}"
  else
    cp "${ROOT}/.tmp-values-veil-offline.yaml" "$dest"
  fi
  rm -f "${ROOT}/.tmp-values-veil-offline.yaml"
  echo "$dest"
}

main() {
  log "tag=${TAG} ssh=${SSH_HOST:-local} profile=${CXADO_VEIL_PROFILE}"

  log "apply namespaces + data plane"
  apply_file "${ROOT}/deploy/k8s/veil-offline/00-namespaces.yaml"
  apply_file "${ROOT}/deploy/k8s/veil-offline/10-nats.yaml"
  apply_file "${ROOT}/deploy/k8s/veil-offline/20-neo4j.yaml"

  VALUES="$(copy_and_sed_values)"
  HELM_ARGS=(-n veil -f "$VALUES")
  if [[ "$WITH_WORKERS_OBS" -eq 1 ]]; then
    if [[ -n "$SSH_HOST" ]]; then
      scp -P "$SSH_PORT" "${ROOT}/deploy/k8s/veil-offline/values-workers-obs.yaml" "${SSH_HOST}:/tmp/values-workers-obs.yaml"
    fi
    HELM_ARGS+=(-f /tmp/values-workers-obs.yaml)
  fi

  log "helm upgrade veil"
  if [[ -n "$SSH_HOST" ]]; then
    rsync -a -e "ssh -p ${SSH_PORT}" "${ROOT}/projects/veil/deploy/helm/veil/" "${SSH_HOST}:/tmp/veil-helm/"
    helm_cmd upgrade --install veil /tmp/veil-helm "${HELM_ARGS[@]}" --set global.imageTag="${TAG}"
  else
    helm_cmd upgrade --install veil "${ROOT}/projects/veil/deploy/helm/veil" "${HELM_ARGS[@]}" --set global.imageTag="${TAG}"
  fi

  log "rollout graph plane"
  kubectl_cmd -n veil rollout status deploy/veil-veil-api --timeout=300s
  kubectl_cmd -n veil rollout status deploy/veil-veil-mcp --timeout=300s

  if [[ "$WITH_WORKERS_OBS" -eq 1 ]]; then
    log "rollout workers (workers-obs)"
    for deploy in veil-veil-ingest-worker veil-veil-pipeline-worker veil-veil-engage-events-worker; do
      kubectl_cmd -n veil rollout status "deploy/${deploy}" --timeout=300s
    done
  fi

  refresh_prometheus_profile

  if [[ "$SMOKE_OBS" -eq 1 && -x "${ROOT}/scripts/k8s/smoke-test-veil-obs.sh" ]]; then
    log "observability smoke"
    CXADO_VEIL_PROFILE="${CXADO_VEIL_PROFILE}" \
      VEIL_OFFLINE_SSH_HOST="$SSH_HOST" VEIL_OFFLINE_SSH_PORT="$SSH_PORT" \
      "${ROOT}/scripts/k8s/smoke-test-veil-obs.sh" || true
  fi

  log "done"
}

main "$@"
