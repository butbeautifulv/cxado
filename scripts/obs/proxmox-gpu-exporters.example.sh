#!/usr/bin/env bash
# DEPRECATED — use scripts/obs/install-gpu-host-exporters.sh
#
# Run on the Proxmox GPU VM (10.8.185.185 / phy-gpu-host01) to expose host + GPU metrics.
#
# Prometheus on k3s (10.8.185.15) scrapes:
#   :9100  node-exporter
#   :9400  dcgm-exporter
# vLLM already serves :11611/metrics (no extra step).
#
# Usage (on GPU VM):
#   sudo ./scripts/obs/install-gpu-host-exporters.sh
exec "$(dirname "$0")/install-gpu-host-exporters.sh" "$@"
