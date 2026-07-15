#!/usr/bin/env bash
# Render deploy/k8s/veil-offline/values-graph-only.yaml with registry + tag placeholders.
#
# Env (from deploy/registry.defaults.env):
#   TAG / VEIL_OFFLINE_TAG, VEIL_IMAGE_REGISTRY
#
# Usage:
#   TAG=abc123 ./scripts/gitlab/render-veil-values.sh > /tmp/values.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALUES_SRC="${ROOT}/deploy/k8s/veil-offline/values-graph-only.yaml"

TAG="${TAG:-${VEIL_OFFLINE_TAG:-${CXADO_OFFLINE_TAG:-${CI_COMMIT_SHORT_SHA:-offline}}}}"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

sed -e "s|__VEIL_OFFLINE_TAG__|${TAG}|g" \
    -e "s|__VEIL_IMAGE_REGISTRY__|${VEIL_IMAGE_REGISTRY}|g" \
    "${VALUES_SRC}"
