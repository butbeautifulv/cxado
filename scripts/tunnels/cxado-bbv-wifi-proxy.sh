#!/usr/bin/env bash
# Persistent TCP proxy on bbv: friendly ports (3000, 8080, …) -> k3s TLS NodePorts.
# Bind on all interfaces so archangelzvuk WiFi clients reach bbv without SSH -L.
#
# Install: sudo ./scripts/tunnels/cxado-bbv-wifi-proxy.sh install
# Status:  ./scripts/tunnels/cxado-bbv-wifi-proxy.sh status
set -euo pipefail

TARGET="${CXADO_NODE_IP}"
UNIT=cxado-k3s-wifi-proxy
BIN=/usr/local/bin/cxado-k3s-wifi-proxy.sh
SERVICE=/etc/systemd/system/${UNIT}.service

declare -A MAP=(
  [3000]=30300
  [8080]=30880
  [3002]=30002
  [3001]=30001
  [9091]=30091
  [8090]=30990
  [8091]=30991
  [7474]=30474
  [30080]=30080
)

proxy_script() {
  cat <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
TARGET="${CXADO_NODE_IP}"
declare -A MAP=(
  [3000]=30300 [8080]=30880 [3002]=30002 [3001]=30001
  [9091]=30091 [8090]=30990 [8091]=30991 [7474]=30474 [30080]=30080
)
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT INT TERM
for local in "${!MAP[@]}"; do
  socat "TCP-LISTEN:${local},fork,reuseaddr,bind=0.0.0.0" "TCP:${TARGET}:${MAP[$local]}" &
  pids+=("$!")
done
wait -n
SCRIPT
}

wifi_ip() {
  ip -4 -o addr show wlo1 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true
}

status() {
  echo "WiFi: $(nmcli -t -f ACTIVE,SSID,DEVICE dev wifi 2>/dev/null | grep '^yes' || echo 'not connected')"
  echo "wlo1 IP: $(wifi_ip || echo n/a)"
  echo "k3s target: ${TARGET}"
  systemctl is-active "${UNIT}" 2>/dev/null || echo "service not installed"
  echo ""
  echo "Listening ports:"
  ss -tlnp 2>/dev/null | grep -E ':('"$(IFS='|'; echo "${!MAP[*]}")"') ' || echo "  (none)"
  echo ""
  echo "URLs (same WiFi / archangelzvuk LAN):"
  local ip
  ip="$(wifi_ip)"
  [[ -n "${ip}" ]] || ip="<wlo1-ip>"
  echo "  egregore-ui:  https://${ip}:3000"
  echo "  egregore-api: https://${ip}:8080/health"
  echo "  grafana:      https://${ip}:3002"
}

install_service() {
  command -v socat >/dev/null || { apt-get update -qq && apt-get install -y socat; }
  proxy_script >"${BIN}"
  chmod 755 "${BIN}"
  cat >"${SERVICE}" <<EOF
[Unit]
Description=cxado k3s WiFi/LAN port proxy (${BIN})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=CXADO_NODE_IP=${TARGET}
ExecStart=${BIN}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "${UNIT}"
  status
}

case "${1:-status}" in
  install) install_service ;;
  status)  status ;;
  *) echo "usage: $0 {install|status}"; exit 1 ;;
esac
