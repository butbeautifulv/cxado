#!/usr/bin/env bash
# Incremental egregore helm upgrade on k3s offline (Nexus pull — no tar import).
#
# Production model:
#   1. Preflight: optional Nexus ctr pull on control plane.
#   2. helm upgrade WITHOUT --wait (never block on unrelated pods).
#   3. Blocking gate: verify-egregore-rollout.sh (api + worker + ui).
#
# Build + push images first:
#   TAG="$(git -C projects/egregore rev-parse --short HEAD)" \
#     ./scripts/k8s/kaniko-build-egregore.sh --tag "${TAG}"
# Or use the entrypoint:
#   ./scripts/k8s/cxado-nexus-deploy.sh --build --tag "${TAG}"
#
# Always passes postgres/redis/bus secrets so empty values cannot wipe secrets.
#
# Usage:
#   CXADO_OFFLINE_TAG=abc123 ./scripts/k8s/egregore-helm-upgrade.sh
#
# Optional replica overrides (values file is SSOT; env vars override at deploy time):
#   EGREGORE_API_REPLICAS=4 EGREGORE_WORKER_REPLICAS=8 EGREGORE_UI_REPLICAS=2
#
# Secrets: POSTGRES_PASSWORD / REDIS_PASSWORD / BUS_SIGNING_KEY from deploy/.secrets/cxado-k3s.env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"
UI_TAG="${CXADO_OFFLINE_UI_TAG:-${TAG}}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SECRETS_ENV_FILE="${CXADO_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/cxado-k3s.env}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
API_REPLICAS_OVERRIDE="${EGREGORE_API_REPLICAS:-}"
WORKER_REPLICAS_OVERRIDE="${EGREGORE_WORKER_REPLICAS:-}"
UI_REPLICAS_OVERRIDE="${EGREGORE_UI_REPLICAS:-}"
SKIP_NEXUS_PREFLIGHT="${SKIP_NEXUS_PREFLIGHT:-0}"

KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
HELM="KUBECONFIG=/home/bbv/.kube/config helm"

log() { printf '[egregore-helm-upgrade] %s\n' "$*"; }
warn() { printf '[egregore-helm-upgrade] WARN: %s\n' "$*" >&2; }
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

export CXADO_IMAGE_REPO="${CXADO_IMAGE_REPO:-${NEXUS_DOCKER_REGISTRY}/${NEXUS_CXADO_DOCKER_REPO}/egregore}"
export CXADO_UI_IMAGE_REPO="${CXADO_UI_IMAGE_REPO:-${NEXUS_DOCKER_REGISTRY}/${NEXUS_CXADO_DOCKER_REPO}/egregore-ui}"

log "tag=${TAG} ui_tag=${UI_TAG} ssh=${SSH_HOST}:${SSH_PORT}"
log "backend=${CXADO_IMAGE_REPO}:${TAG} ui=${CXADO_UI_IMAGE_REPO}:${UI_TAG}"

nexus_preflight_pull() {
  local image_ref="$1"
  if [[ "${SKIP_NEXUS_PREFLIGHT}" == "1" ]]; then
    log "skip Nexus preflight for ${image_ref}"
    return 0
  fi
  log "preflight ctr pull ${image_ref}"
  if ssh -p "${SSH_PORT}" "${SSH_HOST}" \
    "K3S_CONFIG_FILE=/dev/null k3s ctr images pull '${image_ref}'" >/dev/null 2>&1; then
    log "preflight ok: ${image_ref}"
    return 0
  fi
  die "Nexus image missing: ${image_ref} — build first: ./scripts/k8s/kaniko-build-egregore.sh --tag ${TAG}"
}

nexus_preflight_pull "${CXADO_IMAGE_REPO}:${TAG}"

REMOTE_VALUES="/tmp/values-egregore-offline.${TAG}.$$.yaml"
LOCAL_VALUES="$(mktemp)"
trap 'rm -f "${LOCAL_VALUES}"; ssh -p "${SSH_PORT}" "${SSH_HOST}" "rm -f ${REMOTE_VALUES}" >/dev/null 2>&1 || true' EXIT

TAG="${TAG}" CXADO_IMAGE_TAG="${TAG}" \
  "${ROOT}/scripts/gitlab/render-egregore-values.sh" > "${LOCAL_VALUES}"
if grep -q '__CXADO_' "${LOCAL_VALUES}"; then
  die "unresolved placeholder in rendered values"
fi

ssh -p "${SSH_PORT}" "${SSH_HOST}" "cat >${REMOTE_VALUES}" < "${LOCAL_VALUES}"

rsync -a -e "ssh -p ${SSH_PORT}" \
  "${ROOT}/projects/egregore/deploy/helm/egregore" \
  "${SSH_HOST}:/tmp/egregore-helm"

UI_REPLICAS="$(ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "awk '/^ui:/{u=1} u && /^  replicas:/{print \$2; exit}' ${REMOTE_VALUES}" || echo "0")"
if [[ -n "${UI_REPLICAS_OVERRIDE}" ]]; then
  UI_REPLICAS="${UI_REPLICAS_OVERRIDE}"
fi

HELM_EXTRA_SET=()
HELM_CLEAR_NODESEL=()
if ! grep -q 'node-role.kubernetes.io/control-plane' "${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml" 2>/dev/null; then
  HELM_CLEAR_NODESEL=(
    --set-json 'api.nodeSelector=null'
    --set-json 'worker.nodeSelector=null'
    --set-json 'ui.nodeSelector=null'
    --set-json 'api.tolerations=null'
    --set-json 'worker.tolerations=null'
    --set-json 'ui.tolerations=null'
  )
fi
if [[ -n "${API_REPLICAS_OVERRIDE}" ]]; then
  HELM_EXTRA_SET+=(--set "api.replicas=${API_REPLICAS_OVERRIDE}")
fi
if [[ -n "${WORKER_REPLICAS_OVERRIDE}" ]]; then
  HELM_EXTRA_SET+=(--set "worker.replicas=${WORKER_REPLICAS_OVERRIDE}")
  HELM_EXTRA_SET+=(--set "worker.hpa.minReplicas=${WORKER_REPLICAS_OVERRIDE}")
  HELM_EXTRA_SET+=(--set "worker.hpa.maxReplicas=${WORKER_REPLICAS_OVERRIDE}")
fi
if [[ -n "${UI_REPLICAS_OVERRIDE}" ]]; then
  HELM_EXTRA_SET+=(--set "ui.replicas=${UI_REPLICAS_OVERRIDE}")
fi

if [[ "${UI_REPLICAS}" != "0" ]]; then
  nexus_preflight_pull "${CXADO_UI_IMAGE_REPO}:${UI_TAG}"
  log "ui preflight ok (ui.replicas=${UI_REPLICAS})"
else
  log "ui.replicas=0 — skip egregore-ui preflight"
fi

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} create ns ${NS_APP} 2>/dev/null || true"

ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} -n ${NS_APP} get rs -o jsonpath='{range .items[?(@.spec.replicas==0)]}{.metadata.name}{\"\\n\"}{end}'" \
  | while read -r rs; do
      [[ -z "${rs}" ]] && continue
      log "delete stale rs/${rs}"
      ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n ${NS_APP} delete rs/${rs}" || true
    done

ssh -p "${SSH_PORT}" "${SSH_HOST}" bash -s <<REMOTE_HELM
set -euo pipefail
${HELM} upgrade --install egregore /tmp/egregore-helm/egregore -n ${NS_APP} \\
  -f ${REMOTE_VALUES} \\
  --set image.tag='${TAG}' \\
  --set ui.image.tag='${UI_TAG}' \\
  --set postgres.password='${POSTGRES_PASSWORD}' \\
  --set redis.password='${REDIS_PASSWORD}' \\
  --set busSigningKey='${BUS_SIGNING_KEY}' \\
  $(printf '%s ' "${HELM_CLEAR_NODESEL[@]:-}") \\
  $(printf '%s ' "${HELM_EXTRA_SET[@]:-}") \\
  --force-conflicts
REMOTE_HELM

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
    EGREGORE_UI_IMAGE="${CXADO_UI_IMAGE_REPO}:${UI_TAG}" \
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
