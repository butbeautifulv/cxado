#!/usr/bin/env bash
# One-shot SSH port-forward bundle for cxado on k3s.
#
# This forwards local laptop ports to k3s TLS NodePorts on the target node.
# HTTP on forwarded ports auto-redirects to HTTPS on the node.
#
# Requirements:
# - TLS gateway applied via ./scripts/k8s/offline-tls-apply.sh
#
# Usage:
#   ./scripts/tunnels/cxado-k3s-ui-tunnels.sh
#
# Env:
# - CXADO_OFFLINE_SSH_HOST (default: bbv-p30-wifi via scripts/k8s/cxado-offline-env.sh)
# - CXADO_OFFLINE_SSH_PORT (default: 22)
# - CXADO_NODE_IP (default: 192.168.0.133) — for LAN URLs printed below
set -euo pipefail

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NODE_IP="${CXADO_NODE_IP}"

echo "Forwarding via ssh -p ${SSH_PORT} ${SSH_HOST}"
echo ""
echo "Local UIs via tunnel (self-signed TLS; http:// auto-redirects to https://):"
echo "  egregore-ui:  https://localhost:3000"
echo "  egregore-api: https://localhost:8080/health"
echo "  veil-api:     https://localhost:8090/health"
echo "  veil-mcp:     https://localhost:8091/health"
echo "  neo4j:        https://localhost:7474"
echo "  grafana:      https://localhost:3002"
echo "  prometheus:   https://localhost:9091/targets"
echo "  langfuse:     https://localhost:3001"
echo "  arch-docs:    https://localhost:30080"
echo ""
echo "Direct LAN access (no tunnel, from any corp host):"
echo "  egregore-ui:  https://${NODE_IP}:30300"
echo "  egregore-api: https://${NODE_IP}:30880/health"
echo "  veil-api:     https://${NODE_IP}:30990/health"
echo "  veil-mcp:     https://${NODE_IP}:30991/health"
echo "  neo4j:        https://${NODE_IP}:30474"
echo "  grafana:      https://${NODE_IP}:30002"
echo "  prometheus:   https://${NODE_IP}:30091/targets"
echo "  langfuse:     https://${NODE_IP}:30001"
echo "  arch-docs:    https://${NODE_IP}:30080"
echo ""
echo "Trust cert (optional): import deploy/.secrets/tls/tls.crt into browser Authorities"
echo ""
echo "Press Ctrl-C to stop."
echo ""

exec ssh -N \
  -p "${SSH_PORT}" \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  -L 3000:127.0.0.1:30300 \
  -L 8080:127.0.0.1:30880 \
  -L 8090:127.0.0.1:30990 \
  -L 8091:127.0.0.1:30991 \
  -L 7474:127.0.0.1:30474 \
  -L 3002:127.0.0.1:30002 \
  -L 9091:127.0.0.1:30091 \
  -L 3001:127.0.0.1:30001 \
  -L 30080:127.0.0.1:30080 \
  "${SSH_HOST}"
