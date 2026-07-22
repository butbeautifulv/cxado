#!/usr/bin/env bash
# Hard gate after egregore helm upgrade / rollout restart.
#
# Usage:
#   ./scripts/k8s/verify-egregore-rollout.sh
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/verify-egregore-rollout.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS="${CXADO_APP_NS:-cxado-app}"
ROLLOUT_TIMEOUT="${EGREGORE_ROLLOUT_TIMEOUT:-120}"

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

echo "[verify] egregore rollout health (ns=${NS})"

DEPLOYS=(egregore-api tool-gateway)
if kubectl_cmd -n "${NS}" get deploy egregore-dispatcher >/dev/null 2>&1; then
  desired_disp="$(kubectl_cmd -n "${NS}" get deploy egregore-dispatcher -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
  if [[ "${desired_disp}" != "0" ]]; then
    DEPLOYS+=(egregore-dispatcher)
  fi
fi
worker_desired="$(kubectl_cmd -n "${NS}" get deploy egregore-worker -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 0)"
if [[ "${worker_desired}" != "0" ]]; then
  DEPLOYS+=(egregore-worker)
fi

for deploy in "${DEPLOYS[@]}"; do
  if kubectl_cmd -n "${NS}" rollout status "deploy/${deploy}" --timeout="${ROLLOUT_TIMEOUT}s" >/dev/null 2>&1; then
    pass "${deploy} rollout complete"
  else
    bad "${deploy} rollout not complete within ${ROLLOUT_TIMEOUT}s"
  fi
done

app_labels="egregore-api,tool-gateway"
if [[ " ${DEPLOYS[*]} " == *" egregore-dispatcher "* ]]; then
  app_labels="${app_labels},egregore-dispatcher"
fi
if [[ " ${DEPLOYS[*]} " == *" egregore-worker "* ]]; then
  app_labels="${app_labels},egregore-worker"
fi

pending="$(kubectl_cmd get pods -n "${NS}" --field-selector=status.phase=Pending \
  -l "app in (${app_labels})" -o name 2>/dev/null || true)"
if [[ -z "${pending}" ]]; then
  pass "no Pending egregore core pods"
else
  bad "Pending pods: ${pending//$'\n'/; }"
fi

for deploy in "${DEPLOYS[@]}"; do
  line="$(kubectl_cmd -n "${NS}" get deploy "${deploy}" \
    -o custom-columns=READY:.status.readyReplicas,DESIRED:.spec.replicas --no-headers 2>/dev/null || true)"
  ready="${line%% *}"
  desired="${line##* }"
  if [[ -n "${ready}" && -n "${desired}" && "${ready}" == "${desired}" ]]; then
    pass "${deploy} READY==DESIRED (${ready}/${desired})"
  else
    bad "${deploy} READY!=DESIRED (${line:-unknown})"
  fi
done

crash="$(kubectl_cmd get pods -n "${NS}" -l "app in (${app_labels})" \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].state.waiting.reason}{"\n"}{end}' 2>/dev/null \
  | grep -E 'CrashLoopBackOff|Error' || true)"
if [[ -z "${crash}" ]]; then
  pass "no CrashLoopBackOff on core deploys"
else
  bad "unhealthy pods: ${crash//$'\n'/; }"
fi

restarts="$(kubectl_cmd get pods -n "${NS}" -l "app in (${app_labels})" \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null \
  | awk '$2 > 2 {print}' || true)"
if [[ -z "${restarts}" ]]; then
  pass "restart count acceptable (<=2 per pod)"
else
  bad "high restart count: ${restarts//$'\n'/; }"
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "[verify] FAILED — run: ./scripts/k8s/diagnose-pending-pods.sh" >&2
  exit 1
fi

echo "[verify] PASSED"
exit 0
