#!/usr/bin/env bash
# Diagnose cluster DNS from pods on each k3s node (offline 3-node cluster).
#
# Usage:
#   ./scripts/k8s/diagnose-cluster-dns.sh
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/diagnose-cluster-dns.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
LOG_DIR="${CXADO_ARTIFACTS_DIR}/k3s-baseline"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/dns-diagnosis-${STAMP}.log"
DNS_TEST_NS="${CXADO_DNS_TEST_NS:-cxado-dns-test}"
DNS_IMAGE="${CXADO_DNS_TEST_IMAGE:-busybox:1.36}"
FAIL=0

mkdir -p "${LOG_DIR}"

kubectl_cmd() {
  if [[ -n "${SSH_HOST}" ]]; then
    ssh -p "${SSH_PORT}" "${SSH_HOST}" \
      "K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl $(printf '%q ' "$@")"
  else
    kubectl "$@"
  fi
}

section() {
  printf '\n========== %s ==========\n' "$1" | tee -a "${LOG_FILE}"
}

pass() { printf 'PASS %s\n' "$1" | tee -a "${LOG_FILE}"; }
bad() { printf 'FAIL %s\n' "$1" | tee -a "${LOG_FILE}"; FAIL=1; }

section "kube-dns endpoints"
kubectl_cmd -n kube-system get endpoints kube-dns -o wide 2>&1 | tee -a "${LOG_FILE}" || true
kubectl_cmd -n kube-system get pods -l k8s-app=kube-dns -o wide 2>&1 | tee -a "${LOG_FILE}" || true

section "nodes"
kubectl_cmd get nodes -o custom-columns=NAME:.metadata.name,INTERNAL-IP:.status.addresses[0].address,READY:.status.conditions[-1].status 2>&1 | tee -a "${LOG_FILE}"

section "per-node DNS probe (busybox Job)"
kubectl_cmd create ns "${DNS_TEST_NS}" 2>/dev/null || true
kubectl_cmd -n "${DNS_TEST_NS}" delete job -l app=cxado-dns-probe --ignore-not-found 2>/dev/null || true

mapfile -t NODE_LIST < <(kubectl_cmd get nodes --no-headers -o custom-columns=NAME:.metadata.name)
for node in "${NODE_LIST[@]}"; do
  [[ -z "${node}" ]] && continue
  job="dns-probe-${node//./-}"
  job="${job//_/-}"
  section "probe node=${node} job=${job}"
  kubectl_cmd -n "${DNS_TEST_NS}" apply -f - <<EOF 2>&1 | tee -a "${LOG_FILE}"
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  labels:
    app: cxado-dns-probe
spec:
  ttlSecondsAfterFinished: 120
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: ${node}
      containers:
        - name: probe
          image: ${DNS_IMAGE}
          command:
            - sh
            - -c
            - |
              set -e
              echo "resolv.conf:"; cat /etc/resolv.conf
              echo "--- nslookup kubernetes.default"
              nslookup kubernetes.default.svc.cluster.local
              echo "--- nslookup postgres.cxado-data"
              nslookup postgres.cxado-data.svc.cluster.local
              echo "OK"
EOF
  if kubectl_cmd -n "${DNS_TEST_NS}" wait --for=condition=complete "job/${job}" --timeout=90s 2>>"${LOG_FILE}"; then
    kubectl_cmd -n "${DNS_TEST_NS}" logs "job/${job}" 2>&1 | tee -a "${LOG_FILE}"
    pass "DNS probe on ${node}"
  else
    kubectl_cmd -n "${DNS_TEST_NS}" logs "job/${job}" 2>&1 | tee -a "${LOG_FILE}" || true
    kubectl_cmd -n "${DNS_TEST_NS}" describe "job/${job}" 2>&1 | tail -20 | tee -a "${LOG_FILE}" || true
    bad "DNS probe on ${node}"
  fi
done

section "host checks on P30 (via ssh)"
if [[ -n "${SSH_HOST}" ]]; then
  ssh -p "${SSH_PORT}" "${SSH_HOST}" bash -s <<'HOSTCHECK' 2>&1 | tee -a "${LOG_FILE}"
set -euo pipefail
echo "flannel:"; ip link show flannel.1 2>/dev/null || echo "no flannel.1"
echo "ip_forward=$(sysctl -n net.ipv4.ip_forward)"
echo "bridge-nf=$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo n/a)"
echo "KUBE rules: $(iptables-save 2>/dev/null | grep -c KUBE || echo 0)"
HOSTCHECK
fi

section "summary"
if [[ "${FAIL}" -eq 0 ]]; then
  pass "cluster DNS diagnosis"
  echo "log: ${LOG_FILE}"
  exit 0
fi
bad "cluster DNS diagnosis — see ${LOG_FILE}"
exit 1
