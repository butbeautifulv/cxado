#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CXADO_KIND_CLUSTER:-cxado}"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  kind delete cluster --name "$CLUSTER_NAME"
  echo "Deleted kind cluster '$CLUSTER_NAME'"
else
  echo "kind cluster '$CLUSTER_NAME' not found"
fi
