#!/usr/bin/env bash
# Shared SSH / node defaults for cxado offline k3s deploy.
# Source from deploy scripts: source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
#
# Default hop: direct USB WiFi on P30 (see ~/.ssh/config Host bbv-p30-wifi).
# Corp NAT alternative: CXADO_OFFLINE_SSH_HOST=bbv-p30-k44 CXADO_OFFLINE_SSH_PORT=22012
#
# Optional overrides: deploy/.secrets/cxado-k3s.env (gitignored)
# Ansible inventory alternative: deploy/ansible/k3s/inventories/offline/hosts.yml

: "${CXADO_OFFLINE_ENV_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
if [[ -f "${CXADO_OFFLINE_ENV_ROOT}/deploy/.secrets/cxado-k3s.env" ]]; then
  # shellcheck source=/dev/null
  source "${CXADO_OFFLINE_ENV_ROOT}/deploy/.secrets/cxado-k3s.env"
fi

export CXADO_OFFLINE_SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
export CXADO_OFFLINE_SSH_PORT="${CXADO_OFFLINE_SSH_PORT:-22}"
export CXADO_NODE_IP="${CXADO_NODE_IP:-192.168.0.133}"
export CXADO_NODE_HOSTNAME="${CXADO_NODE_HOSTNAME:-bbv-p30-k44}"
# Corp NAT IP — include in TLS SAN when LAN IP is WiFi (both URLs must work in browser).
export CXADO_TLS_SAN_IP_EXTRA="${CXADO_TLS_SAN_IP_EXTRA:-10.8.185.15}"
export CXADO_OBS_NS="${CXADO_OBS_NS:-cxado-obs}"
