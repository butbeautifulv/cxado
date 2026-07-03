#!/usr/bin/env bash
# Fresh Langfuse bootstrap on k3s offline (remote) — mirrors local `make dev-langfuse-fresh`.
#
# Headless init (LANGFUSE_INIT_*) runs only on an empty Postgres DB. This script wipes
# Langfuse PVCs, reapplies manifests, and wires egregore with the same API keys as local dev.
#
# Usage:
#   source deploy/.secrets/cxado-k3s.env
#   ./scripts/k8s/langfuse-k3s-bootstrap.sh
#
# Env:
#   CXADO_OFFLINE_SSH_HOST (default: bbv@10.8.184.22)
#   CXADO_OFFLINE_SSH_PORT (default: 22012)
#   CXADO_NODE_IP (default: 10.8.185.15)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NODE_IP="${CXADO_NODE_IP}"
KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
HELM="KUBECONFIG=/home/bbv/.kube/config helm"
NS="cxado-langfuse"

SECRETS_ENV="${CXADO_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/cxado-k3s.env}"
LANGFUSE_ENV="${LANGFUSE_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/langfuse-k3s.env}"

log() { printf '[langfuse-k3s-bootstrap] %s\n' "$*"; }

remote() {
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "$@"
}

apply() {
  remote "${KCTL} apply -f -" < "$1"
}

if [[ -f "${SECRETS_ENV}" ]]; then
  # shellcheck disable=SC1090
  set -a; source "${SECRETS_ENV}"; set +a
fi

need() {
  local v="$1"
  if [[ -z "${!v:-}" ]]; then
    echo "missing env: ${v} (set in ${SECRETS_ENV})" >&2
    exit 2
  fi
}

need POSTGRES_PASSWORD
need REDIS_PASSWORD

if [[ ! -f "${LANGFUSE_ENV}" ]]; then
  log "generating langfuse secrets env"
  CXADO_NODE_IP="${NODE_IP}" "${ROOT}/scripts/k8s/langfuse-create-secrets.sh"
fi
# shellcheck disable=SC1090
set -a; source "${LANGFUSE_ENV}"; set +a

log "ensure langfuse k8s secret (preserve existing credentials)"
SECRET_YAML="$(mktemp)"
trap 'rm -f "${SECRET_YAML}"' EXIT
cat >"${SECRET_YAML}" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: langfuse-secrets
  namespace: ${NS}
type: Opaque
stringData:
  postgres-password: ${LANGFUSE_POSTGRES_PASSWORD}
  redis-auth: ${LANGFUSE_REDIS_AUTH}
  clickhouse-password: ${LANGFUSE_CLICKHOUSE_PASSWORD}
  minio-root-user: ${LANGFUSE_MINIO_ROOT_USER}
  minio-root-password: ${LANGFUSE_MINIO_ROOT_PASSWORD}
  nextauth-secret: ${LANGFUSE_NEXTAUTH_SECRET}
  salt: ${LANGFUSE_SALT}
  encryption-key: ${LANGFUSE_ENCRYPTION_KEY}
  nextauth-url: https://${NODE_IP}:30001
  database-url: ${LANGFUSE_DATABASE_URL}
EOF
remote "${KCTL} get ns ${NS} >/dev/null 2>&1 || ${KCTL} create ns ${NS}"
remote "${KCTL} apply -f -" < "${SECRET_YAML}"

log "scale down langfuse workloads (all deps — release PVCs before delete)"
remote "${KCTL} -n ${NS} scale deploy/langfuse-web deploy/langfuse-worker deploy/postgres deploy/redis deploy/clickhouse deploy/minio --replicas=0" || true
remote "${KCTL} -n ${NS} wait --for=delete pod -l app=langfuse-postgres --timeout=120s" 2>/dev/null || true
remote "${KCTL} -n ${NS} wait --for=delete pod -l app=langfuse-redis --timeout=120s" 2>/dev/null || true
remote "${KCTL} -n ${NS} wait --for=delete pod -l app=clickhouse --timeout=120s" 2>/dev/null || true
remote "${KCTL} -n ${NS} wait --for=delete pod -l app=langfuse-minio --timeout=120s" 2>/dev/null || true

log "delete langfuse data PVCs (fresh headless init)"
for pvc in \
  langfuse-postgres-data \
  langfuse-redis-data \
  langfuse-minio-data \
  langfuse-clickhouse-data \
  langfuse-clickhouse-logs; do
  remote "${KCTL} -n ${NS} delete pvc ${pvc} --ignore-not-found --wait=true" || true
done

log "apply langfuse manifests"
for f in \
  "${ROOT}/deploy/k8s/langfuse-offline/00-namespace.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/10-postgres.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/11-redis.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/12-clickhouse.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/13-minio.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/15-configmap.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/20-langfuse.yaml"; do
  apply "$f"
done

log "wait for infra"
remote "${KCTL} -n ${NS} rollout status deploy/postgres --timeout=300s"
remote "${KCTL} -n ${NS} rollout status deploy/redis --timeout=180s"
remote "${KCTL} -n ${NS} rollout status deploy/clickhouse --timeout=300s"
remote "${KCTL} -n ${NS} rollout status deploy/minio --timeout=180s"

log "minio bucket init"
remote "${KCTL} -n ${NS} delete job minio-init --ignore-not-found"
apply "${ROOT}/deploy/k8s/langfuse-offline/14-minio-init-job.yaml"
remote "${KCTL} -n ${NS} wait --for=condition=complete job/minio-init --timeout=180s"

log "start langfuse (headless init on first boot)"
remote "${KCTL} -n ${NS} scale deploy/langfuse-web deploy/langfuse-worker --replicas=1"
remote "${KCTL} -n ${NS} rollout status deploy/langfuse-web --timeout=300s"
remote "${KCTL} -n ${NS} rollout status deploy/langfuse-worker --timeout=300s"

log "verify headless init in postgres"
remote "${KCTL} -n ${NS} exec deploy/postgres -- psql -U langfuse -d langfuse -tAc \"SELECT count(*) FROM organizations;\""

log "upgrade egregore with Langfuse API keys"
remote "cat >/tmp/values-egregore-offline.yaml" < "${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml"
remote "${KCTL} create ns cxado-app 2>/dev/null || true"
rsync -a -e "ssh -p ${SSH_PORT}" \
  "${ROOT}/projects/egregore/deploy/helm/egregore" \
  "${SSH_HOST}:/tmp/egregore-helm"
remote "${HELM} upgrade --install egregore /tmp/egregore-helm/egregore -n cxado-app \
  -f /tmp/values-egregore-offline.yaml \
  --set postgres.password='${POSTGRES_PASSWORD}' \
  --set redis.password='${REDIS_PASSWORD}' \
  --set langfuse.publicKey='pk-lf-egregore-dev-local' \
  --set langfuse.secretKey='sk-lf-egregore-dev-local'"
remote "${KCTL} -n cxado-app rollout status deploy/egregore-api --timeout=180s"
remote "${KCTL} -n cxado-app rollout status deploy/egregore-worker --timeout=180s"

log "done"
echo ""
echo "Langfuse UI:  https://${NODE_IP}:30001"
echo "Login:        dev@egregore.local / egregore-dev"
echo "API keys:     pk-lf-egregore-dev-local / sk-lf-egregore-dev-local"
echo "Egregore:     LANGFUSE_HOST + keys wired via helm upgrade"
echo ""
log "configure LLM connection + LLM-as-Judge evaluators"
LANGFUSE_HOST="https://${NODE_IP}:30001" LANGFUSE_INSECURE_TLS=1 \
  "${ROOT}/scripts/k8s/langfuse-k3s-setup-judge.sh" || {
  echo "[langfuse-k3s-bootstrap] WARN: judge setup failed (is vLLM reachable from cluster?)" >&2
}
