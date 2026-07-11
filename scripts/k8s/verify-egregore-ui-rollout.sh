#!/usr/bin/env bash
# Optional gate for egregore-ui when ui.replicas > 0.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-20260709 ./scripts/k8s/verify-egregore-ui-rollout.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS="${CXADO_APP_NS:-cxado-app}"
TAG="${CXADO_OFFLINE_TAG:-}"
UI_IMAGE="${EGREGORE_UI_IMAGE:-cxado/egregore-ui:${TAG}}"
ROLLOUT_TIMEOUT="${EGREGORE_UI_ROLLOUT_TIMEOUT:-300}"

fail=0
pass() { printf 'OK   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

kubectl_cmd() {
  if [[ -n "${SSH_HOST}" ]]; then
    # shellcheck disable=SC2029
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
  else
    kubectl "$@"
  fi
}

echo "[verify-ui] egregore-ui rollout (ns=${NS})"

desired="$(kubectl_cmd -n "${NS}" get deploy egregore-ui \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")"
if [[ "${desired}" == "0" || -z "${desired}" ]]; then
  pass "egregore-ui scaled to 0 (skipped)"
  exit 0
fi

if [[ -x "${ROOT}/scripts/k8s/k3s-image-imported.sh" ]]; then
  if "${ROOT}/scripts/k8s/k3s-image-imported.sh" "${UI_IMAGE}"; then
    pass "ui image imported (${UI_IMAGE})"
  else
    bad "ui image missing (${UI_IMAGE}) — run: CXADO_OFFLINE_TAG=${TAG:-<tag>} ./scripts/k8s/k3s-offline-bundle-egregore-ui.sh"
  fi
fi

if kubectl_cmd -n "${NS}" rollout status deploy/egregore-ui --timeout="${ROLLOUT_TIMEOUT}s" >/dev/null 2>&1; then
  pass "egregore-ui rollout complete"
else
  bad "egregore-ui rollout not complete within ${ROLLOUT_TIMEOUT}s"
fi

ready="$(kubectl_cmd -n "${NS}" get deploy egregore-ui \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
if [[ "${ready}" == "${desired}" ]]; then
  pass "egregore-ui READY==DESIRED (${ready}/${desired})"
else
  bad "egregore-ui READY!=DESIRED (${ready:-0}/${desired})"
fi

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi
echo "[verify-ui] PASSED"
exit 0
