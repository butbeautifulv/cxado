#!/usr/bin/env bash
# Incremental egregore helm upgrade on k3s offline (no full redeploy).
#
# Always passes postgres/redis passwords so empty values file cannot wipe secrets.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD-msgfix \
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-k44 \
#   ./scripts/k8s/egregore-helm-upgrade.sh
#
# Secrets: POSTGRES_PASSWORD / REDIS_PASSWORD from env or deploy/.secrets/cxado-k3s.env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SECRETS_ENV_FILE="${CXADO_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/cxado-k3s.env}"
NS_APP="${CXADO_APP_NS:-cxado-app}"

KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
HELM="KUBECONFIG=/home/bbv/.kube/config helm"

log() { printf '[egregore-helm-upgrade] %s\n' "$*"; }

if [[ -f "${SECRETS_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a; source "${SECRETS_ENV_FILE}"; set +a
fi

if [[ -z "${POSTGRES_PASSWORD:-}" || -z "${REDIS_PASSWORD:-}" ]]; then
  echo "missing POSTGRES_PASSWORD or REDIS_PASSWORD (env or ${SECRETS_ENV_FILE})" >&2
  exit 2
fi

log "tag=${TAG} ssh=${SSH_HOST}:${SSH_PORT}"

ssh -p "${SSH_PORT}" "${SSH_HOST}" "cat >/tmp/values-egregore-offline.yaml" \
  < "${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "sed -i 's/__CXADO_OFFLINE_TAG__/${TAG}/g' /tmp/values-egregore-offline.yaml"

rsync -a -e "ssh -p ${SSH_PORT}" \
  "${ROOT}/projects/egregore/deploy/helm/egregore" \
  "${SSH_HOST}:/tmp/egregore-helm"

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} create ns ${NS_APP} 2>/dev/null || true"

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${HELM} upgrade --install egregore /tmp/egregore-helm/egregore -n ${NS_APP} \
  -f /tmp/values-egregore-offline.yaml \
  --set image.tag='${TAG}' \
  --set ui.image.tag='${TAG}' \
  --set postgres.password='${POSTGRES_PASSWORD}' \
  --set redis.password='${REDIS_PASSWORD}' \
  --wait --timeout 10m"

for deploy in egregore-api egregore-worker egregore-ui; do
  log "rollout ${deploy}"
  ssh -p "${SSH_PORT}" "${SSH_HOST}" \
    "${KCTL} -n ${NS_APP} rollout status deploy/${deploy} --timeout=300s"
done

if [[ -x "${ROOT}/scripts/k8s/smoke-test-egregore-obs.sh" ]]; then
  log "observability smoke"
  CXADO_OFFLINE_SSH_HOST="${SSH_HOST}" CXADO_OFFLINE_SSH_PORT="${SSH_PORT}" \
    "${ROOT}/scripts/k8s/smoke-test-egregore-obs.sh" || true
fi

log "done"
