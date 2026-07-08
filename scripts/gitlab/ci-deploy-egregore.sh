#!/usr/bin/env bash
# Helm upgrade egregore on local P30 k3s (CI runner host).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TAG="$(cat "${ROOT}/.ci/image-tag")"
NS_APP="${CXADO_APP_NS:-cxado-app}"
VALUES_SRC="${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml"
CHART="${ROOT}/projects/egregore/deploy/helm/egregore"

KCTL="k3s kubectl"
HELM="helm"

log() { printf '[ci-deploy-egregore] %s\n' "$*"; }

for var in POSTGRES_PASSWORD REDIS_PASSWORD; do
  if [[ -z "${!var:-}" ]]; then
    echo "missing CI variable: ${var}" >&2
    exit 2
  fi
done

if [[ -z "${BUS_SIGNING_KEY:-}" ]]; then
  BUS_SIGNING_KEY="$(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
  log "generated ephemeral BUS_SIGNING_KEY"
fi

if [[ ! -d "${CHART}" ]]; then
  echo "missing helm chart: ${CHART}" >&2
  exit 2
fi

VALUES="/tmp/values-egregore-ci-${TAG}.yaml"
sed "s/__CXADO_OFFLINE_TAG__/${TAG}/g" "${VALUES_SRC}" > "${VALUES}"

export KUBECONFIG="${KUBECONFIG:-/home/bbv/.kube/config}"

log "helm upgrade tag=${TAG} ns=${NS_APP}"
${KCTL} create ns "${NS_APP}" 2>/dev/null || true

${HELM} upgrade --install egregore "${CHART}" -n "${NS_APP}" \
  -f "${VALUES}" \
  --set "image.tag=${TAG}" \
  --set "ui.image.tag=${TAG}" \
  --set "postgres.password=${POSTGRES_PASSWORD}" \
  --set "redis.password=${REDIS_PASSWORD}" \
  --set "busSigningKey=${BUS_SIGNING_KEY}" \
  --force-conflicts \
  --wait --timeout 15m

for deploy in egregore-api egregore-worker; do
  log "rollout ${deploy}"
  ${KCTL} -n "${NS_APP}" rollout status "deploy/${deploy}" --timeout=300s
done

log "done"
