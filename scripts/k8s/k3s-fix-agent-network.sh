#!/usr/bin/env bash
# Apply k3s networking sysctl + flannel firewall on offline cluster nodes.
#
# Usage:
#   ./scripts/k8s/k3s-fix-agent-network.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
# shellcheck disable=SC1090
[[ -f "${ROOT}/deploy/.secrets/cxado-k3s.env" ]] && source "${ROOT}/deploy/.secrets/cxado-k3s.env"

P30_IP="10.8.185.15"
VM01_IP="10.20.16.195"
VM02_IP="10.20.16.185"
PEERS=("${P30_IP}" "${VM01_IP}" "${VM02_IP}")

log() { printf '[k3s-fix-agent-network] %s\n' "$*"; }

apply_sysctl_remote() {
  local host="$1" pw="$2"
  ssh "${host}" "printf '%s\n' '${pw}' | sudo -S -p '' bash -s" <<'SYSCTL'
set -euo pipefail
modprobe br_netfilter 2>/dev/null || true
modprobe overlay 2>/dev/null || true
cat >/etc/modules-load.d/k3s.conf <<'EOF'
br_netfilter
overlay
EOF
cat >/etc/sysctl.d/99-k3s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF
sysctl --system >/dev/null
echo "ip_forward=$(sysctl -n net.ipv4.ip_forward)"
echo "bridge-nf=$(sysctl -n net.bridge.bridge-nf-call-iptables)"
SYSCTL
}

apply_flannel_fw_remote() {
  local host="$1" pw="$2" use_ufw="${3:-0}"
  ssh "${host}" "printf '%s\n' '${pw}' | sudo -S -p '' USE_UFW='${use_ufw}' bash -s" <<'FW'
set -euo pipefail
PEERS=(10.8.185.15 10.20.16.195 10.20.16.185)
if [[ "${USE_UFW}" == "1" ]] && command -v ufw >/dev/null 2>&1; then
  for peer in "${PEERS[@]}"; do
    [[ "${peer}" == "$(hostname -I | awk '{print $1}')" ]] && continue
    ufw allow from "${peer}" to any port 8472 proto udp comment "k3s flannel vxlan" 2>/dev/null || true
  done
  ufw allow from 10.42.0.0/16 comment "k3s pod cidr" 2>/dev/null || true
  ufw allow from 10.43.0.0/16 comment "k3s service cidr" 2>/dev/null || true
  echo "ufw flannel rules on $(hostname)"
fi
# Flannel VXLAN + pod/service CIDR between cluster nodes (idempotent).
for peer in "${PEERS[@]}"; do
  iptables -C INPUT -p udp --dport 8472 -s "${peer}" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p udp --dport 8472 -s "${peer}" -j ACCEPT
  iptables -C OUTPUT -p udp --dport 8472 -d "${peer}" -j ACCEPT 2>/dev/null || \
    iptables -I OUTPUT -p udp --dport 8472 -d "${peer}" -j ACCEPT
done
for cidr in 10.42.0.0/16 10.43.0.0/16; do
  iptables -C INPUT -s "${cidr}" -j ACCEPT 2>/dev/null || iptables -I INPUT -s "${cidr}" -j ACCEPT
  iptables -C OUTPUT -d "${cidr}" -j ACCEPT 2>/dev/null || iptables -I OUTPUT -d "${cidr}" -j ACCEPT
done
echo "flannel-fw ok on $(hostname)"
FW
}

restart_agent() {
  local host="$1" pw="$2"
  ssh "${host}" "printf '%s\n' '${pw}' | sudo -S -p '' systemctl restart k3s-agent && sleep 5 && systemctl is-active k3s-agent"
}

log "sysctl + firewall vm-01"
apply_sysctl_remote vm-01 "${VM_01_PWD:-}"
apply_flannel_fw_remote vm-01 "${VM_01_PWD:-}"

log "sysctl + firewall vm-02"
apply_sysctl_remote vm-02 "${VM_02_PWD:-}"
apply_flannel_fw_remote vm-02 "${VM_02_PWD:-}"

log "sysctl + firewall P30 (ufw)"
apply_sysctl_remote bbv-p30-wifi "${CXADO_OFFLINE_SUDO_PW:-}"
apply_flannel_fw_remote bbv-p30-wifi "${CXADO_OFFLINE_SUDO_PW:-}" 1

log "restart k3s-agent on workers"
restart_agent vm-01 "${VM_01_PWD:-}"
restart_agent vm-02 "${VM_02_PWD:-}"

log "kube-proxy rule counts"
for host in vm-01 vm-02; do
  pw="${VM_01_PWD:-}"; [[ "$host" == "vm-02" ]] && pw="${VM_02_PWD:-}"
  cnt="$(ssh "${host}" "printf '%s\n' '${pw}' | sudo -S -p '' iptables-save 2>/dev/null | grep -c KUBE || true")"
  log "${host}: KUBE rules=${cnt}"
done

log "done"
