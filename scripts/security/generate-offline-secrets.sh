#!/usr/bin/env bash
# Generate local-only secrets env file for offline k3s deploy.
#
# Output: deploy/.secrets/cxado-k3s.env (ignored by git)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"
OUT="${CXADO_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/cxado-k3s.env}"

mkdir -p "$(dirname "$OUT")"

rand() {
  # 32 bytes base64, URL-safe-ish
  openssl rand -base64 32 | tr -d '\n' | tr '+/' '-_' | tr -d '='
}

cat >"$OUT" <<EOF
CXADO_OFFLINE_SSH_HOST=bbv@0.0.0.0
CXADO_OFFLINE_SSH_PORT=22012

# Fill this manually (NOT printed anywhere by deploy script)
CXADO_OFFLINE_SUDO_PW=

POSTGRES_PASSWORD=$(rand)
REDIS_PASSWORD=$(rand)
NEO4J_PASSWORD=$(rand)
BUS_SIGNING_KEY=$(rand)
EOF

chmod 600 "$OUT"
echo "wrote $OUT"
echo "next: edit CXADO_OFFLINE_SUDO_PW in that file"

