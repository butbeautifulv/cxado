#!/usr/bin/env bash
# P30 WiFi: friendly ports (3000, 8080, …) on 192.168.0.x -> k3s NodePorts on localhost.
#
# Usage:
#   ./scripts/tunnels/cxado-p30-wifi-k3s-proxy.sh install
#   ./scripts/tunnels/cxado-p30-wifi-k3s-proxy.sh status
#
# Then from same WiFi LAN (no SSH tunnel):
#   https://192.168.0.133:3000   egregore-ui
#   https://192.168.0.133:8080   egregore-api
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
# shellcheck source=/dev/null
[[ -f "${ROOT}/deploy/.secrets/cxado-k3s.env" ]] && source "${ROOT}/deploy/.secrets/cxado-k3s.env"

SSH_TARGET="${CXADO_P30_SSH:-bbv-p30-wifi}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:?set CXADO_OFFLINE_SUDO_PW}"
PROXY_PY="${ROOT}/scripts/tunnels/cxado-k3s-wifi-proxy.py"
UNIT=cxado-k3s-wifi-proxy
PORTS="3000 8080 3002 3001 9091 8090 8091 7474 30080"
WIFI_CIDR="${CXADO_WIFI_CIDR:-192.168.0.0/24}"

remote() { ssh -o BatchMode=yes "${SSH_TARGET}" "$@"; }

remote_sudo() {
  remote "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' bash -s"
}

usage() {
  echo "usage: $0 {install|status} [SSH_TARGET]"
  exit 1
}

cmd="${1:-status}"
[[ $# -gt 1 ]] && SSH_TARGET="$2"

case "${cmd}" in
  install)
    scp -q "${PROXY_PY}" "${SSH_TARGET}:/tmp/cxado-k3s-wifi-proxy.py"
    remote_sudo <<REMOTE
set -euo pipefail
install -m 755 /tmp/cxado-k3s-wifi-proxy.py /usr/local/bin/cxado-k3s-wifi-proxy.py
cat >/etc/systemd/system/${UNIT}.service <<'EOF'
[Unit]
Description=cxado k3s WiFi port proxy (3000 -> NodePorts)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=CXADO_NODE_IP=127.0.0.1
ExecStart=/usr/bin/python3 /usr/local/bin/cxado-k3s-wifi-proxy.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl unmask ${UNIT} 2>/dev/null || true
systemctl enable --now ${UNIT}
for p in ${PORTS}; do
  ufw allow from ${WIFI_CIDR} to any port "\$p" proto tcp comment 'cxado wifi k3s proxy' 2>/dev/null || true
done
REMOTE
    echo "[install] done on ${SSH_TARGET}"
    ;;
  status)
    remote "systemctl is-active ${UNIT}; ss -tlnp | grep -E ':(3000|8080|3002) ' || true; ip -4 -o addr | grep wl"
    ;;
  *) usage ;;
esac

WIFI_IP="$(ssh -o BatchMode=yes -G "${SSH_TARGET}" 2>/dev/null | awk '/^hostname /{print $2}')"
cat <<EOF

WiFi URLs (https, self-signed cert):
  egregore-ui:  https://${WIFI_IP}:3000
  egregore-api: https://${WIFI_IP}:8080/health
  veil-api:     https://${WIFI_IP}:8090/health
  veil-mcp:     https://${WIFI_IP}:8091/health
  grafana:      https://${WIFI_IP}:3002
  prometheus:   https://${WIFI_IP}:9091/targets
  langfuse:     https://${WIFI_IP}:3001
  neo4j:        https://${WIFI_IP}:7474
  arch-docs:    https://${WIFI_IP}:30080
EOF
