#!/usr/bin/env bash
# Incremental egregore helm upgrade on k3s offline (no full redeploy).
#
# Production model:
#   1. Preflight: backend + egregore-ui images must exist in k3s containerd.
#   2. helm upgrade WITHOUT --wait (never block on unrelated pods).
#   3. Blocking gate: verify-egregore-rollout.sh (api + worker + ui).
#
# Bundle UI before upgrade:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD ./scripts/k8s/k3s-offline-bundle-egregore-ui.sh
#
# Always passes postgres/redis/bus secrets so empty values cannot wipe secrets.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD-msgfix ./scripts/k8s/egregore-helm-upgrade.sh
#
# Optional UI enable after bundle:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD EGREGORE_UI_REPLICAS=2 ./scripts/k8s/egregore-helm-upgrade.sh
#
# Secrets: POSTGRES_PASSWORD / REDIS_PASSWORD / BUS_SIGNING_KEY from deploy/.secrets/cxado-k3s.env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SECRETS_ENV_FILE="${CXADO_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/cxado-k3s.env}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
UI_REPLICAS_OVERRIDE="${EGREGORE_UI_REPLICAS:-}"

KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
HELM="KUBECONFIG=/home/bbv/.kube/config helm"

log() { printf '[egregore-helm-upgrade] %s\n' "$*"; }
die() { printf '[egregore-helm-upgrade] ERROR: %s\n' "$*" >&2; exit 1; }

if [[ -f "${SECRETS_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a; source "${SECRETS_ENV_FILE}"; set +a
fi

if [[ -z "${POSTGRES_PASSWORD:-}" || -z "${REDIS_PASSWORD:-}" ]]; then
  die "missing POSTGRES_PASSWORD or REDIS_PASSWORD (env or ${SECRETS_ENV_FILE})"
fi

if [[ -z "${BUS_SIGNING_KEY:-}" ]]; then
  BUS_SIGNING_KEY="$(openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"
  log "generated ephemeral BUS_SIGNING_KEY (set in ${SECRETS_ENV_FILE} to persist)"
fi

log "tag=${TAG} ssh=${SSH_HOST}:${SSH_PORT}"

BACKEND_IMAGE="cxado/egregore:${TAG}"
if ! "${ROOT}/scripts/k8s/k3s-image-imported.sh" "${BACKEND_IMAGE}"; then
  die "import backend first: CXADO_OFFLINE_TAG=${TAG} ./scripts/k8s/k3s-offline-bundle-egregore.sh"
fi
log "preflight ok: ${BACKEND_IMAGE}"

ssh -p "${SSH_PORT}" "${SSH_HOST}" "cat >/tmp/values-egregore-offline.yaml" \
  < "${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "sed -i 's/__CXADO_OFFLINE_TAG__/${TAG}/g' /tmp/values-egregore-offline.yaml"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "sed -i 's|__CXADO_IMAGE_REPO__|cxado/egregore|g' /tmp/values-egregore-offline.yaml"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "sed -i 's|__CXADO_UI_IMAGE_REPO__|cxado/egregore-ui|g' /tmp/values-egregore-offline.yaml"

rsync -a -e "ssh -p ${SSH_PORT}" \
  "${ROOT}/projects/egregore/deploy/helm/egregore" \
  "${SSH_HOST}:/tmp/egregore-helm"

UI_REPLICAS="$(ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "awk '/^ui:/{u=1} u && /^  replicas:/{print \$2; exit}' /tmp/values-egregore-offline.yaml" || echo "0")"
if [[ -n "${UI_REPLICAS_OVERRIDE}" ]]; then
  UI_REPLICAS="${UI_REPLICAS_OVERRIDE}"
fi

HELM_EXTRA_SET=()
if [[ -n "${UI_REPLICAS_OVERRIDE}" ]]; then
  HELM_EXTRA_SET+=(--set "ui.replicas=${UI_REPLICAS_OVERRIDE}")
fi

if [[ "${UI_REPLICAS}" != "0" ]]; then
  UI_IMAGE="cxado/egregore-ui:${TAG}"
  if ! "${ROOT}/scripts/k8s/k3s-image-imported.sh" "${UI_IMAGE}"; then
    die "ui.replicas=${UI_REPLICAS} but image missing — bundle first: CXADO_OFFLINE_TAG=${TAG} ./scripts/k8s/k3s-offline-bundle-egregore-ui.sh (or set ui.replicas=0 / omit EGREGORE_UI_REPLICAS)"
  fi
  log "preflight ok: ${UI_IMAGE} (ui.replicas=${UI_REPLICAS})"
else
  log "ui.replicas=0 — skip egregore-ui preflight"
fi

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} create ns ${NS_APP} 2>/dev/null || true"

# No --wait: deployments verified explicitly below (api/worker blocking; UI optional).
ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${HELM} upgrade --install egregore /tmp/egregore-helm/egregore -n ${NS_APP} \
  -f /tmp/values-egregore-offline.yaml \
  --set image.tag='${TAG}' \
  --set ui.image.tag='${TAG}' \
  --set postgres.password='${POSTGRES_PASSWORD}' \
  --set redis.password='${REDIS_PASSWORD}' \
  --set busSigningKey='${BUS_SIGNING_KEY}' \
  ${HELM_EXTRA_SET[*]:-} \
  --force-conflicts"

log "helm upgrade applied (no global --wait)"

if [[ -x "${ROOT}/scripts/k8s/verify-egregore-rollout.sh" ]]; then
  log "blocking gate: api + worker"
  CXADO_OFFLINE_SSH_HOST="${SSH_HOST}" CXADO_OFFLINE_SSH_PORT="${SSH_PORT}" \
    "${ROOT}/scripts/k8s/verify-egregore-rollout.sh"
else
  for deploy in egregore-api egregore-worker; do
    log "rollout ${deploy}"
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "${KCTL} -n ${NS_APP} rollout status deploy/${deploy} --timeout=300s"
  done
fi

if [[ "${UI_REPLICAS}" != "0" ]]; then
  log "blocking gate: egregore-ui (replicas=${UI_REPLICAS})"
  CXADO_OFFLINE_TAG="${TAG}" CXADO_OFFLINE_SSH_HOST="${SSH_HOST}" CXADO_OFFLINE_SSH_PORT="${SSH_PORT}" \
    "${ROOT}/scripts/k8s/verify-egregore-ui-rollout.sh"
else
  log "skip egregore-ui verify (replicas=0)"
fi

log "catalog seed + reload (sync agents/ from image to Postgres)"
if ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n ${NS_APP} exec deploy/egregore-api -- /app/.venv/bin/egregore catalog seed" >>/dev/null 2>&1; then
  log "OK  egregore catalog seed"
else
  warn "egregore catalog seed failed (non-blocking for helm; run manually)"
fi
if ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n ${NS_APP} exec deploy/egregore-api -- /app/.venv/bin/python -c 'from cys_core.infrastructure.catalog.catalog_registry import reload_agent_registry; reload_agent_registry()'" >>/dev/null 2>&1; then
  log "OK  catalog registry reload"
else
  warn "catalog registry reload failed"
fi
CRITIC_RECIPIENTS="$(ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n ${NS_APP} exec deploy/egregore-api -- /app/.venv/bin/python -c \"
from bootstrap.container import get_container
agent = get_container().get_agent_catalog().get_agent('critic')
print(','.join(agent.bus_recipients) if agent else '')
\" 2>/dev/null" || true)"
if [[ "${CRITIC_RECIPIENTS}" == *intel* ]]; then
  log "OK  critic.bus_recipients includes intel (${CRITIC_RECIPIENTS})"
else
  die "critic.bus_recipients missing intel: ${CRITIC_RECIPIENTS:-unknown} — run catalog seed manually"
fi

if [[ -x "${ROOT}/scripts/k8s/smoke-test-egregore-obs.sh" ]]; then
  log "observability smoke (non-blocking)"
  CXADO_OFFLINE_SSH_HOST="${SSH_HOST}" CXADO_OFFLINE_SSH_PORT="${SSH_PORT}" \
    "${ROOT}/scripts/k8s/smoke-test-egregore-obs.sh" || true
fi

log "done"
