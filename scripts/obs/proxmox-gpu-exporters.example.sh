#!/usr/bin/env bash
# Run on the Proxmox GPU VM (10.8.185.186) to expose host + GPU metrics for Prometheus.
#
# Prometheus on k3s (10.8.185.15) scrapes:
#   :9100  node-exporter
#   :9400  dcgm-exporter
# vLLM already serves :11612/metrics (no extra step).
#
# Usage (on GPU VM):
#   sudo ./scripts/obs/proxmox-gpu-exporters.example.sh
set -euo pipefail

NODE_EXPORTER_IMAGE="${NODE_EXPORTER_IMAGE:-prom/node-exporter:v1.9.1}"
DCGM_EXPORTER_IMAGE="${DCGM_EXPORTER_IMAGE:-nvcr.io/nvidia/k8s/dcgm-exporter:3.3.8-3.6.0-ubuntu22.04}"

docker rm -f proxmox-node-exporter proxmox-dcgm-exporter 2>/dev/null || true

docker run -d --name proxmox-node-exporter --restart unless-stopped \
  --net host --pid host \
  -v /:/host:ro,rslave \
  "${NODE_EXPORTER_IMAGE}" \
  --path.rootfs=/host \
  --web.listen-address=:9100 \
  --collector.filesystem.mount-points-exclude='^/(dev|proc|sys|run|var/lib/docker)(/|$)'

docker run -d --name proxmox-dcgm-exporter --restart unless-stopped \
  --gpus all \
  -p 9400:9400 \
  "${DCGM_EXPORTER_IMAGE}"

echo "node-exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "dcgm-exporter: http://$(hostname -I | awk '{print $1}'):9400/metrics"
echo "vLLM metrics:  http://$(hostname -I | awk '{print $1}'):11612/metrics"
