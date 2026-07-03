#!/usr/bin/env bash
# Configure Langfuse LLM-as-Judge on k3s offline (runs setup via SSH on the node).
#
# Usage:
#   source deploy/.secrets/cxado-k3s.env
#   ./scripts/k8s/langfuse-k3s-setup-judge.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NODE_IP="${CXADO_NODE_IP}"
VALUES_FILE="${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml"

# shellcheck disable=SC1091
[[ -f "${ROOT}/deploy/.secrets/cxado-k3s.env" ]] && source "${ROOT}/deploy/.secrets/cxado-k3s.env"

LLM_BASE_URL="${LLM_BASE_URL:-$(grep -E '^[[:space:]]*baseUrl:' "${VALUES_FILE}" | head -1 | sed -E 's/.*baseUrl:[[:space:]]*"?([^"]+)"?.*/\1/')}"
LLM_MODEL="${LLM_MODEL:-$(grep -E '^[[:space:]]*model:' "${VALUES_FILE}" | head -1 | sed -E 's/.*model:[[:space:]]*"?([^"]+)"?.*/\1/')}"

SCRIPT_REMOTE=/tmp/langfuse-setup-llm-judge.sh
scp -P "${SSH_PORT}" "${ROOT}/projects/egregore/scripts/langfuse-setup-llm-judge.sh" "${SSH_HOST}:${SCRIPT_REMOTE}"
ssh -p "${SSH_PORT}" "${SSH_HOST}" "chmod +x ${SCRIPT_REMOTE} && \
  LANGFUSE_HOST=https://127.0.0.1:30001 \
  LANGFUSE_INSECURE_TLS=1 \
  LANGFUSE_PUBLIC_KEY='${LANGFUSE_PUBLIC_KEY:-pk-lf-egregore-dev-local}' \
  LANGFUSE_SECRET_KEY='${LANGFUSE_SECRET_KEY:-sk-lf-egregore-dev-local}' \
  LANGFUSE_USER_EMAIL='${LANGFUSE_USER_EMAIL:-dev@egregore.local}' \
  LANGFUSE_USER_PASSWORD='${LANGFUSE_USER_PASSWORD:-egregore-dev}' \
  LANGFUSE_PROJECT_ID='${LANGFUSE_PROJECT_ID:-egregore-dev}' \
  LLM_BASE_URL='${LLM_BASE_URL}' \
  LLM_MODEL='${LLM_MODEL}' \
  ${SCRIPT_REMOTE}"

echo ""
echo "Langfuse UI: https://${NODE_IP}:30001"
echo "LLM connection: egregore-vllm -> ${LLM_BASE_URL}"
echo "Judge model id (Langfuse): ${LLM_MODEL#openai/}"
