#!/usr/bin/env bash
# Create cxado secrets in-cluster (cxado-data namespace).
#
# Usage:
#   POSTGRES_PASSWORD=... REDIS_PASSWORD=... NEO4J_PASSWORD=... ./scripts/k8s/cxado-create-secrets.sh
#
# Notes:
# - Keeps secrets out of git.
set -euo pipefail

NS="${CXADO_DATA_NS:-cxado-data}"

need() {
  local v="$1"
  if [[ -z "${!v:-}" ]]; then
    echo "missing env: ${v}" >&2
    exit 2
  fi
}

need POSTGRES_PASSWORD
need REDIS_PASSWORD
need NEO4J_PASSWORD

kubectl get ns "${NS}" >/dev/null 2>&1 || kubectl create ns "${NS}"

kubectl -n "${NS}" delete secret cxado-credentials >/dev/null 2>&1 || true
kubectl -n "${NS}" create secret generic cxado-credentials \
  --from-literal=postgres-password="${POSTGRES_PASSWORD}" \
  --from-literal=redis-password="${REDIS_PASSWORD}" \
  --from-literal=neo4j-password="${NEO4J_PASSWORD}" \
  --from-literal=neo4j-auth="neo4j/${NEO4J_PASSWORD}"

echo "created secret cxado-credentials in ${NS}"

