#!/usr/bin/env bash
set -euo pipefail

CTX="${KUBE_CONTEXT:-kind-cxado}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

echo "=== nodes ==="
kubectl --context "$CTX" get nodes -o wide 2>/dev/null || kubectl get nodes -o wide

for ns in cxado-data cxado-app veil cxado-obs ingress-nginx; do
  echo ""
  echo "=== pods -n $ns ==="
  kubectl get pods -n "$ns" 2>/dev/null || echo "(namespace missing)"
done

echo ""
echo "=== health (host ports via kind mappings) ==="
for url in \
  "http://127.0.0.1:8080/health|egregore-api" \
  "http://127.0.0.1:8090/health|veil-api" \
  "http://127.0.0.1:8091/health|veil-mcp" \
  "http://127.0.0.1:3002/api/health|grafana"; do
  IFS='|' read -r u label <<< "$url"
  if curl -fsS -o /dev/null -m 3 "$u" 2>/dev/null; then
    echo "OK  $label"
  else
    echo "FAIL $label ($u)"
  fi
done
