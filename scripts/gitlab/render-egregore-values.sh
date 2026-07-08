#!/usr/bin/env bash
# Render deploy/k8s/cxado-offline/values-egregore-offline.yaml with registry + tag placeholders.
#
# Env (from GitLab CI vars or deploy/registry.defaults.env):
#   CXADO_IMAGE_TAG / TAG, CXADO_IMAGE_REPO, CXADO_UI_IMAGE_REPO
#
# Usage:
#   TAG=abc123 ./scripts/gitlab/render-egregore-values.sh > /tmp/values.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALUES_SRC="${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml"

TAG="${TAG:-${CXADO_IMAGE_TAG:-${CI_COMMIT_SHORT_SHA:-offline}}}"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

sed -e "s|__CXADO_OFFLINE_TAG__|${TAG}|g" \
    -e "s|__CXADO_IMAGE_REPO__|${CXADO_IMAGE_REPO}|g" \
    -e "s|__CXADO_UI_IMAGE_REPO__|${CXADO_UI_IMAGE_REPO}|g" \
    "${VALUES_SRC}"
