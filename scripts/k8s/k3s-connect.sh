#!/usr/bin/env bash
# Connect to cxado P30 k3s from the laptop: SSH tunnel + kubeconfig + k9s/kubectl.
#
# Usage:
#   ./scripts/k8s/k3s-connect.sh              # open k9s (default)
#   ./scripts/k8s/k3s-connect.sh k9s
#   ./scripts/k8s/k3s-connect.sh kubectl get nodes
#   ./scripts/k8s/k3s-connect.sh tunnel start|stop|status
#   ./scripts/k8s/k3s-connect.sh export       # refresh kubeconfig from the node
#   ./scripts/k8s/k3s-connect.sh env            # print shell exports
#   ./scripts/k8s/k3s-connect.sh status
#
# Optional env (see deploy/.secrets/cxado-k3s.env):
#   CXADO_OFFLINE_SSH_HOST, CXADO_LENS_LOCAL_PORT, CXADO_LENS_CLUSTER_NAME
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

TUNNEL_SH="${ROOT}/scripts/k8s/lens-tunnel.sh"
EXPORT_SH="${ROOT}/scripts/k8s/lens-export-kubeconfig.sh"
KUBECONFIG_PATH="${ROOT}/deploy/.secrets/kubeconfig-cxado-p30.yaml"
LOCAL_PORT="${CXADO_LENS_LOCAL_PORT:-16443}"
CLUSTER_NAME="${CXADO_LENS_CLUSTER_NAME:-cxado-p30}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"

usage() {
  cat <<EOF
usage: $(basename "$0") [command] [args...]

commands:
  (default)           start tunnel, ensure kubeconfig, launch k9s
  k9s                 same as default
  kubectl [args...]   start tunnel, ensure kubeconfig, run kubectl
  tunnel start|stop|status
  export              refresh ${KUBECONFIG_PATH}
  env                 print export KUBECONFIG=... for your shell
  status              tunnel + API connectivity check

SSH hop: ${SSH_HOST}
API:     https://127.0.0.1:${LOCAL_PORT} (via SSH tunnel)
config:  ${KUBECONFIG_PATH}
EOF
}

find_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    command -v kubectl
    return 0
  fi
  for candidate in \
    /home/linuxbrew/.linuxbrew/bin/kubectl \
    "${HOME}/.local/bin/kubectl" \
    /usr/local/bin/kubectl; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

ensure_tunnel() {
  if ! "${TUNNEL_SH}" status >/dev/null 2>&1; then
    echo "starting SSH tunnel to ${SSH_HOST} ..."
    "${TUNNEL_SH}" start
  fi
}

ensure_kubeconfig() {
  if [[ ! -f "${KUBECONFIG_PATH}" ]]; then
    echo "kubeconfig missing — fetching from ${SSH_HOST} ..."
    "${EXPORT_SH}"
    return 0
  fi

  if ! grep -q "server: https://127.0.0.1:${LOCAL_PORT}" "${KUBECONFIG_PATH}" 2>/dev/null; then
    echo "kubeconfig looks stale — refreshing ..."
    "${EXPORT_SH}"
  fi
}

api_reachable() {
  curl -sk -o /dev/null "https://127.0.0.1:${LOCAL_PORT}/" 2>/dev/null
}

print_env() {
  cat <<EOF
export KUBECONFIG="${KUBECONFIG_PATH}"
# cluster context: ${CLUSTER_NAME}
# then: k9s   or   kubectl get nodes
EOF
}

cmd_status() {
  echo "SSH host:   ${SSH_HOST}"
  echo "kubeconfig: ${KUBECONFIG_PATH}"
  if [[ -f "${KUBECONFIG_PATH}" ]]; then
    echo "context:    $(grep '^current-context:' "${KUBECONFIG_PATH}" | awk '{print $2}')"
    echo "api server: $(grep 'server:' "${KUBECONFIG_PATH}" | head -1 | awk '{print $2}')"
  else
    echo "kubeconfig: (missing — run: $(basename "$0") export)"
  fi
  echo ""
  if api_reachable; then
    echo "tunnel:     up (127.0.0.1:${LOCAL_PORT})"
  else
    echo "tunnel:     down — run: $(basename "$0") tunnel start"
    return 1
  fi
}

cmd_k9s() {
  ensure_tunnel
  ensure_kubeconfig
  export KUBECONFIG="${KUBECONFIG_PATH}"
  if ! command -v k9s >/dev/null 2>&1; then
    echo "k9s not found. Install: brew install k9s" >&2
    exit 1
  fi
  exec k9s --context "${CLUSTER_NAME}" "$@"
}

cmd_kubectl() {
  ensure_tunnel
  ensure_kubeconfig
  export KUBECONFIG="${KUBECONFIG_PATH}"
  local kubectl_bin
  if ! kubectl_bin="$(find_kubectl)"; then
    cat >&2 <<EOF
kubectl not found.

Install one of:
  brew install kubectl
  sudo snap install kubectl --classic

Or use k9s instead:
  $(basename "$0") k9s
EOF
    exit 1
  fi
  exec "${kubectl_bin}" --context "${CLUSTER_NAME}" "$@"
}

main() {
  local cmd="${1:-k9s}"
  case "${cmd}" in
    -h|--help|help)
      usage
      ;;
    k9s)
      shift || true
      cmd_k9s "$@"
      ;;
    kubectl)
      shift
      cmd_kubectl "$@"
      ;;
    tunnel)
      shift
      exec "${TUNNEL_SH}" "${1:-status}"
      ;;
    export)
      ensure_tunnel
      exec "${EXPORT_SH}"
      ;;
    env)
      ensure_tunnel
      ensure_kubeconfig
      print_env
      ;;
    status)
      cmd_status
      ;;
    *)
      echo "unknown command: ${cmd}" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
