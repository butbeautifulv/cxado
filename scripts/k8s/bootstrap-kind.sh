#!/usr/bin/env bash
# Create cxado kind cluster + ingress-nginx + metrics-server.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLUSTER_NAME="${CXADO_KIND_CLUSTER:-cxado}"
KIND_CONFIG="${ROOT}/deploy/k8s/kind/cxado-kind.yaml"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is required: https://kind.sigs.k8s.io/" >&2
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "kind cluster '$CLUSTER_NAME' already exists"
else
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

echo "Installing ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "Patching ingress for cxado host port mappings..."
kubectl patch svc ingress-nginx-controller -n ingress-nginx --type=json -p='[
  {"op":"add","path":"/spec/ports/0/nodePort","value":30080},
  {"op":"replace","path":"/spec/type","value":"NodePort"}
]' 2>/dev/null || true

echo "Installing metrics-server (for HPA)..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}
]' 2>/dev/null || true

echo "kind cluster '$CLUSTER_NAME' ready. KUBECONFIG context: kind-${CLUSTER_NAME}"
