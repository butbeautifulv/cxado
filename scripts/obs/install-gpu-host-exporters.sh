#!/usr/bin/env bash
# Install node-exporter + dcgm-exporter on the GPU VM (phy-gpu-host01).
#
# Run ON THE GPU HOST (not on k3s P30):
#   sudo ./scripts/obs/install-gpu-host-exporters.sh
#
# Env:
#   NODE_EXPORTER_PORT=9100
#   DCGM_EXPORTER_PORT=9400
#   GPU_METRICS_BIND=0.0.0.0  (node-exporter uses --net host)
set -euo pipefail

NODE_EXPORTER_IMAGE="${NODE_EXPORTER_IMAGE:-prom/node-exporter:v1.9.1}"
DCGM_EXPORTER_IMAGE="${DCGM_EXPORTER_IMAGE:-nvcr.io/nvidia/k8s/dcgm-exporter:3.3.8-3.6.0-ubuntu22.04}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
DCGM_EXPORTER_PORT="${DCGM_EXPORTER_PORT:-9400}"

log() { printf '[gpu-exporters] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
  die "docker not found — install Docker + NVIDIA Container Toolkit first"
fi

if ! docker info >/dev/null 2>&1; then
  die "docker not usable (permission denied? run with sudo)"
fi

log "remove old containers"
docker rm -f proxmox-node-exporter proxmox-dcgm-exporter 2>/dev/null || true

log "start node-exporter :${NODE_EXPORTER_PORT}"
docker run -d --name proxmox-node-exporter --restart unless-stopped \
  --net host --pid host \
  -v /:/host:ro,rslave \
  "${NODE_EXPORTER_IMAGE}" \
  --path.rootfs=/host \
  --web.listen-address=":${NODE_EXPORTER_PORT}" \
  --collector.filesystem.mount-points-exclude='^/(dev|proc|sys|run|var/lib/docker)(/|$)'

log "start dcgm-exporter :${DCGM_EXPORTER_PORT}"
DCGM_OK=0
if docker run -d --name proxmox-dcgm-exporter --restart unless-stopped \
  --gpus all \
  -p "${DCGM_EXPORTER_PORT}:9400" \
  "${DCGM_EXPORTER_IMAGE}" 2>/dev/null; then
  sleep 3
  if curl -fsS "http://127.0.0.1:${DCGM_EXPORTER_PORT}/metrics" 2>/dev/null | grep -q DCGM_FI_DEV_GPU_UTIL; then
    DCGM_OK=1
    log "dcgm-exporter (docker --gpus all) OK"
  else
    log "dcgm-exporter container up but no GPU metrics — trying fallback"
    docker rm -f proxmox-dcgm-exporter 2>/dev/null || true
  fi
else
  log "dcgm-exporter docker --gpus all failed (no nvidia-container-toolkit?)"
fi

if [[ "${DCGM_OK}" -eq 0 ]]; then
  log "install nvidia-smi fallback exporter on :${DCGM_EXPORTER_PORT}"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  FALLBACK="${SCRIPT_DIR}/gpu-metrics-exporter-fallback.py"
  [[ -f "${FALLBACK}" ]] || die "missing ${FALLBACK}"
  install -m 0755 "${FALLBACK}" /usr/local/bin/gpu-metrics-exporter.py
  cat > /etc/systemd/system/gpu-metrics-exporter.service <<UNIT
[Unit]
Description=GPU metrics exporter (nvidia-smi fallback on :${DCGM_EXPORTER_PORT})
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/gpu-metrics-exporter.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now gpu-metrics-exporter.service
  sleep 2
  systemctl is-active --quiet gpu-metrics-exporter.service \
    || die "gpu-metrics-exporter.service failed — check journalctl -u gpu-metrics-exporter"
  log "gpu-metrics-exporter (systemd fallback) OK"
fi

sleep 1
curl -fsS "http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics" | head -3 >/dev/null \
  || die "node-exporter not responding on :${NODE_EXPORTER_PORT}"
curl -fsS "http://127.0.0.1:${DCGM_EXPORTER_PORT}/metrics" | grep -q DCGM_FI_DEV_GPU_UTIL \
  || die "GPU metrics not responding on :${DCGM_EXPORTER_PORT}"

HOST_IP="$(hostname -I | awk '{print $1}')"
log "OK node-exporter: http://${HOST_IP}:${NODE_EXPORTER_PORT}/metrics"
log "OK dcgm-exporter: http://${HOST_IP}:${DCGM_EXPORTER_PORT}/metrics"
log "Prometheus on P30 should scrape up{job=~\"proxmox-gpu-.*\"}==1 after firewall allows 10.8.185.15"
