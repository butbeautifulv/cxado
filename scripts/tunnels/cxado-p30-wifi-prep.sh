#!/usr/bin/env bash
# Prepare bbv-P30-K44 for USB WiFi dongle (archangelzvuk) without losing corp/k3s routing.
#
# Run from laptop while P30 is reachable via corp NAT:
#   source deploy/.secrets/cxado-k3s.env
#   ./scripts/tunnels/cxado-p30-wifi-prep.sh
#
# Env: CXADO_OFFLINE_SSH_HOST, CXADO_OFFLINE_SSH_PORT, CXADO_OFFLINE_SUDO_PW
#      CXADO_WIFI_PSK (default: PSK from local nmcli archangelzvuk_5G profile)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=/dev/null
[[ -f "${ROOT}/deploy/.secrets/cxado-k3s.env" ]] && source "${ROOT}/deploy/.secrets/cxado-k3s.env"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv@10.8.184.22}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT:-22012}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:?set CXADO_OFFLINE_SUDO_PW}"
PSK="${CXADO_WIFI_PSK:-$(nmcli -s -g 802-11-wireless-security.psk connection show archangelzvuk_5G)}"

remote() {
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "$@"
}

remote_sudo() {
  remote "printf '%s\n' '${SUDO_PW}' | sudo -S -p '' bash -s" "$@"
}

echo "[p30-wifi-prep] target ${SSH_HOST}:${SSH_PORT}"

remote_sudo <<REMOTE
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -qq -y wireless-tools wpasupplicant 2>/dev/null || true

for ssid in archangelzvuk_5G archangelzvuk; do
  nmcli connection delete "\$ssid" 2>/dev/null || true
  prio=100; [[ "\$ssid" == archangelzvuk ]] && prio=90
  nmcli connection add type wifi ifname "*" con-name "\$ssid" ssid "\$ssid" \\
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk '${PSK}' \\
    ipv4.method auto ipv4.never-default yes ipv4.route-metric 500 \\
    connection.autoconnect yes connection.autoconnect-priority "\$prio"
done

nmcli connection modify netplan-enp1s0 ipv4.route-metric 100

mkdir -p /etc/sysctl.d /etc/ssh/sshd_config.d
cat >/etc/sysctl.d/99-cxado-dual-nic.conf <<'EOF'
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
EOF
sysctl --system >/dev/null 2>&1 || true

cat >/etc/ssh/sshd_config.d/99-cxado-wifi.conf <<'EOF'
Port 22
Port 22012
EOF
systemctl stop ssh.socket 2>/dev/null || true
systemctl disable ssh.socket 2>/dev/null || true
systemctl enable --now ssh.service
systemctl restart ssh

echo "[p30-wifi-prep] profiles:"
nmcli connection show archangelzvuk_5G | grep -E 'ssid|never-default|autoconnect'
ss -tlnp | grep sshd || ss -tlnp | grep ':22'
REMOTE

echo "[p30-wifi-prep] done. Plug USB WiFi on P30; then from laptop:"
echo "  nmcli connection show archangelzvuk_5G  # on P30 via ssh, check DHCP IP"
echo "  ssh bbv@<p30-wifi-ip>   # direct, same LAN — no corp NAT"
