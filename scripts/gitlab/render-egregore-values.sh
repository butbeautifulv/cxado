#!/usr/bin/env bash
# Render deploy/k8s/cxado-offline/values-egregore-offline.yaml with registry + tag placeholders.
#
# Env (from GitLab CI vars or deploy/registry.defaults.env):
#   CXADO_IMAGE_TAG / TAG, CXADO_API_IMAGE_REPO, CXADO_DISPATCHER_IMAGE_REPO,
#   CXADO_AGENT_RUNTIME_IMAGE_REPO, CXADO_TOOL_GATEWAY_IMAGE_REPO, CXADO_UI_IMAGE_REPO
#
# Usage:
#   TAG=abc123 ./scripts/gitlab/render-egregore-values.sh > /tmp/values.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALUES_SRC="${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml"

TAG="${TAG:-${CXADO_IMAGE_TAG:-${CI_COMMIT_SHORT_SHA:-offline}}}"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

CXADO_API_IMAGE_REPO="${CXADO_API_IMAGE_REPO:-${CXADO_IMAGE_REPO:-${CXADO_CI_REGISTRY}/egregore-api}}"
CXADO_DISPATCHER_IMAGE_REPO="${CXADO_DISPATCHER_IMAGE_REPO:-${CXADO_CI_REGISTRY}/egregore-dispatcher}"
CXADO_AGENT_RUNTIME_IMAGE_REPO="${CXADO_AGENT_RUNTIME_IMAGE_REPO:-${CXADO_CI_REGISTRY}/egregore-agent-runtime}"
CXADO_TOOL_GATEWAY_IMAGE_REPO="${CXADO_TOOL_GATEWAY_IMAGE_REPO:-${CXADO_CI_REGISTRY}/egregore-tool-gateway}"

sed -e "s|__CXADO_OFFLINE_TAG__|${TAG}|g" \
    -e "s|__CXADO_API_IMAGE_REPO__|${CXADO_API_IMAGE_REPO}|g" \
    -e "s|__CXADO_DISPATCHER_IMAGE_REPO__|${CXADO_DISPATCHER_IMAGE_REPO}|g" \
    -e "s|__CXADO_AGENT_RUNTIME_IMAGE_REPO__|${CXADO_AGENT_RUNTIME_IMAGE_REPO}|g" \
    -e "s|__CXADO_TOOL_GATEWAY_IMAGE_REPO__|${CXADO_TOOL_GATEWAY_IMAGE_REPO}|g" \
    -e "s|__CXADO_UI_IMAGE_REPO__|${CXADO_UI_IMAGE_REPO}|g" \
    "${VALUES_SRC}"
