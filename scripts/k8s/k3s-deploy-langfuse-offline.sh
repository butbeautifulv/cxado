#!/usr/bin/env bash
# Deploy Langfuse offline stack to k3s via SSH hop.
#
# Usage:
#   source deploy/.secrets/cxado-k3s.env
#   ./scripts/k8s/k3s-deploy-langfuse-offline.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"
NODE_IP="${CXADO_NODE_IP}"
KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"

SECRETS_ENV="${LANGFUSE_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/langfuse-k3s.env}"

apply() {
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} apply -f -" < "$1"
}

log() { printf '[langfuse-deploy] %s\n' "$*"; }

log "generate secrets env"
CXADO_NODE_IP="${NODE_IP}" "${ROOT}/scripts/k8s/langfuse-create-secrets.sh"
# shellcheck disable=SC1090
set -a; source "${SECRETS_ENV}"; set +a

log "create k8s secret"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} get ns cxado-langfuse >/dev/null 2>&1 || ${KCTL} create ns cxado-langfuse"
SECRET_YAML="$(mktemp)"
trap 'rm -f "${SECRET_YAML}"' EXIT
cat >"${SECRET_YAML}" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: langfuse-secrets
  namespace: cxado-langfuse
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
  nextauth-url: ${LANGFUSE_NEXTAUTH_URL}
  database-url: ${LANGFUSE_DATABASE_URL}
EOF
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} apply -f -" < "${SECRET_YAML}"

for f in \
  "${ROOT}/deploy/k8s/langfuse-offline/00-namespace.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/10-postgres.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/11-redis.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/12-clickhouse.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/13-minio.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/15-configmap.yaml" \
  "${ROOT}/deploy/k8s/langfuse-offline/20-langfuse.yaml"; do
  log "apply $(basename "$f")"
  apply "$f"
done

log "wait for infra"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse rollout status deploy/postgres --timeout=180s"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse rollout status deploy/redis --timeout=180s"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse rollout status deploy/clickhouse --timeout=300s"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse rollout status deploy/minio --timeout=180s"

log "minio bucket init"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse delete job minio-init --ignore-not-found"
apply "${ROOT}/deploy/k8s/langfuse-offline/14-minio-init-job.yaml"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse wait --for=condition=complete job/minio-init --timeout=180s"

log "start langfuse"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse rollout status deploy/langfuse-web --timeout=300s"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} -n cxado-langfuse rollout status deploy/langfuse-worker --timeout=300s"

log "update tls gateway for langfuse nodeport"
"${ROOT}/scripts/k8s/offline-tls-apply.sh"

log "done"
echo ""
echo "Langfuse UI:"
echo "  https://${NODE_IP}:30001"
echo "  https://localhost:3001 (via tunnel)"
echo "Login: dev@egregore.local / egregore-dev"
echo "Project keys: pk-lf-egregore-dev-local / sk-lf-egregore-dev-local"
echo ""
echo "For fresh headless init on existing cluster: ./scripts/k8s/langfuse-k3s-bootstrap.sh"
