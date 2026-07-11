#!/usr/bin/env bash
# Deploy DefectDojo stack to k3s (cxado-aspm) and bootstrap product + API token.
#
# Usage:
#   ./scripts/k8s/k3s-deploy-defectdojo.sh
#   ./scripts/k8s/k3s-deploy-defectdojo.sh --skip-mirror
#   ./scripts/k8s/k3s-deploy-defectdojo.sh --skip-init
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

MANIFEST_DIR="${ROOT}/deploy/k8s/defectdojo-offline"
SECRETS_ENV="${ROOT}/deploy/.secrets/cxado-k3s.env"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
NS_ASPM="${CXADO_ASPM_NS:-cxado-aspm}"
NS_DATA="${CXADO_DATA_NS:-cxado-data}"
DD_URL="${DEFECTDOJO_URL:-http://defectdojo.cxado-aspm.svc.cluster.local:8080}"
KCTL="${CXADO_K3S_KUBECTL:-K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl}"
SKIP_MIRROR=false
SKIP_INIT=false

log() { printf '[k3s-deploy-defectdojo] %s\n' "$*"; }
die() { echo "[k3s-deploy-defectdojo] ERROR: $*" >&2; exit 2; }

rand_secret() {
  python3 -c 'import secrets; print(secrets.token_urlsafe(48))'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-mirror) SKIP_MIRROR=true; shift ;;
    --skip-init) SKIP_INIT=true; shift ;;
    *) die "unknown arg: $1" ;;
  esac
done

[[ -f "${SECRETS_ENV}" ]] && source "${SECRETS_ENV}"

remote() {
  ssh -p "${SSH_PORT}" "${SSH_HOST}" "$@"
}

rand_hex32() {
  python3 -c 'import secrets; print(secrets.token_hex(16))'
}

ensure_nexus_registry() {
  local reg user pass
  reg="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
  user="${NEXUS_USER:-}"
  pass="${NEXUS_PASSWORD:-}"
  [[ -n "${user}" && -n "${pass}" ]] || die "NEXUS_USER/NEXUS_PASSWORD required in ${SECRETS_ENV}"

  log "ensure nexus-registry pull secret (cxado-aspm + cxado-data)"
  for ns in "${NS_ASPM}" "${NS_DATA}"; do
    remote env REG="${reg}" USER="${user}" PASS="${pass}" NS="${ns}" bash -s <<'EOS'
set -euo pipefail
kctl() { K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl "$@"; }
kctl -n "${NS}" create secret docker-registry nexus-registry \
  --docker-server="${REG}" \
  --docker-username="${USER}" \
  --docker-password="${PASS}" \
  --dry-run=client -o yaml | kctl apply -f -
EOS
  done
}

ensure_secrets() {
  local pg_pass secret_key aes_key admin_pass db_url
  pg_pass="${DEFECTDOJO_PG_PASSWORD:-${POSTGRES_PASSWORD:-}}"
  if [[ -z "${pg_pass}" ]]; then
    pg_pass="$(rand_hex32)"
    log "generated defectdojo postgres password"
  fi
  secret_key="${DEFECTDOJO_SECRET_KEY:-$(rand_secret)}"
  aes_key="${DEFECTDOJO_CREDENTIAL_AES_KEY:-$(rand_hex32)}"
  admin_pass="${DD_ADMIN_PASSWORD:-${VM_01_DEFECTDOJO_SU_PWD:-admin}}"
  db_url="postgresql://defectdojo:${pg_pass}@defectdojo-postgres.cxado-data.svc.cluster.local:5432/defectdojo"

  log "apply defectdojo-secrets (cxado-aspm + cxado-data)"
  remote "${KCTL} create ns ${NS_ASPM} 2>/dev/null || true"
  remote "${KCTL} create ns ${NS_DATA} 2>/dev/null || true"
  remote "${KCTL} -n ${NS_ASPM} delete secret defectdojo-secrets --ignore-not-found"
  remote "${KCTL} -n ${NS_DATA} delete secret defectdojo-secrets --ignore-not-found"

  remote env \
    PG_PASS="${pg_pass}" SECRET_KEY="${secret_key}" AES_KEY="${aes_key}" \
    ADMIN_PASS="${admin_pass}" DB_URL="${db_url}" NS_ASPM="${NS_ASPM}" NS_DATA="${NS_DATA}" \
    bash -s <<'EOS'
set -euo pipefail
kctl() { K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl "$@"; }
for ns in "${NS_ASPM}" "${NS_DATA}"; do
  args=(create secret generic defectdojo-secrets --from-literal=postgres-password="${PG_PASS}")
  if [[ "${ns}" == "${NS_ASPM}" ]]; then
    args+=(
      --from-literal=secret-key="${SECRET_KEY}"
      --from-literal=credential-aes-key="${AES_KEY}"
      --from-literal=admin-password="${ADMIN_PASS}"
      --from-literal=database-url="${DB_URL}"
    )
  fi
  kctl -n "${ns}" "${args[@]}"
done
EOS
}

apply_base() {
  log "apply base manifests"
  for f in 00-namespace.yaml 10-postgres.yaml 11-redis.yaml 12-pvc-media.yaml 20-configmap.yaml 40-resource-quota.yaml; do
    scp -P "${SSH_PORT}" "${MANIFEST_DIR}/${f}" "${SSH_HOST}:/tmp/dd-${f}"
    remote "${KCTL} apply -f /tmp/dd-${f}"
  done
}

wait_postgres() {
  log "wait defectdojo-postgres"
  remote "${KCTL} -n ${NS_DATA} rollout status deploy/defectdojo-postgres --timeout=300s"
  remote "${KCTL} -n ${NS_ASPM} rollout status deploy/defectdojo-redis --timeout=180s"
}

run_initializer() {
  log "run defectdojo initializer job"
  scp -P "${SSH_PORT}" "${MANIFEST_DIR}/15-initializer-job.yaml" "${SSH_HOST}:/tmp/dd-initializer.yaml"
  remote "${KCTL} -n ${NS_ASPM} delete job defectdojo-initializer --ignore-not-found --wait=true"
  remote "${KCTL} apply -f /tmp/dd-initializer.yaml"
  remote "${KCTL} -n ${NS_ASPM} wait --for=condition=complete job/defectdojo-initializer --timeout=600s"
  remote "${KCTL} -n ${NS_ASPM} patch configmap defectdojo-config --type merge -p '{\"data\":{\"DD_INITIALIZE\":\"false\"}}'"
}

apply_apps() {
  log "apply defectdojo app deployments"
  scp -P "${SSH_PORT}" "${MANIFEST_DIR}/20-defectdojo.yaml" "${SSH_HOST}:/tmp/dd-apps.yaml"
  remote "${KCTL} apply -f /tmp/dd-apps.yaml"
  remote "${KCTL} -n ${NS_ASPM} rollout status deploy/defectdojo-uwsgi --timeout=600s"
  remote "${KCTL} -n ${NS_ASPM} rollout status deploy/defectdojo-nginx --timeout=300s"
  remote "${KCTL} -n ${NS_ASPM} rollout status deploy/defectdojo-celeryworker --timeout=300s"
  remote "${KCTL} -n ${NS_ASPM} rollout status deploy/defectdojo-celerybeat --timeout=300s"
}

bootstrap_api() {
  local admin_user admin_pass token
  admin_user="${VM_01_DEFECTDOJO_SU_NAME:-admin}"
  admin_pass="${DD_ADMIN_PASSWORD:-${VM_01_DEFECTDOJO_SU_PWD:-admin}}"

  log "bootstrap API token + product egregore"
  token="$(remote env DD_URL="${DD_URL}" ADMIN_USER="${admin_user}" ADMIN_PASS="${admin_pass}" bash -s <<'EOS'
set -euo pipefail
kctl() { K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl "$@"; }
for _ in $(seq 1 36); do
  tok=$(kctl -n cxado-aspm run dd-bootstrap --rm -i --restart=Never \
    --image=nexus.svo.aero:8345/cxado-docker/alpine:3.20.3 \
    --command -- sh -c "
      wget -qO- --header='Content-Type: application/json' \
        --post-data='{\"username\":\"'\"${ADMIN_USER}\"'\",\"password\":\"'\"${ADMIN_PASS}\"'\"}' \
        '${DD_URL}/api/v2/api-token-auth/' 2>/dev/null \
      | sed -n 's/.*\"token\":\"\\([^\"]*\\)\".*/\\1/p'
    " 2>/dev/null | tail -1)
  if [ -n "${tok}" ] && [ "${tok}" != "All" ]; then
    echo "${tok}"
    exit 0
  fi
  sleep 10
done
exit 1
EOS
)" || die "could not obtain DefectDojo API token"

  [[ -n "${token}" ]] || die "empty API token"
  log "API token obtained"

  remote env DD_URL="${DD_URL}" TOKEN="${token}" bash -s <<'EOS'
set -euo pipefail
kctl() { K3S_CONFIG_FILE=/dev/null KUBECONFIG=/home/bbv/.kube/config k3s kubectl "$@"; }
kctl -n cxado-aspm run dd-product --rm -i --restart=Never \
  --image=nexus.svo.aero:8345/cxado-docker/alpine:3.20.3 \
  --command -- sh -c "
    wget -qO /tmp/out --header='Authorization: Token ${TOKEN}' \
      --header='Content-Type: application/json' \
      --post-data='{\"name\":\"egregore\",\"description\":\"Egregore secure CI/CD\",\"prod_type\":1}' \
      '${DD_URL}/api/v2/products/' 2>/dev/null || true
    grep -q egregore /tmp/out 2>/dev/null
  "
EOS

  if [[ -f "${SECRETS_ENV}" ]]; then
    if grep -q '^DEFECTDOJO_API_TOKEN=' "${SECRETS_ENV}" 2>/dev/null; then
      sed -i "s|^DEFECTDOJO_API_TOKEN=.*|DEFECTDOJO_API_TOKEN=${token}|" "${SECRETS_ENV}"
    else
      printf '\nDEFECTDOJO_API_TOKEN=%s\n' "${token}" >> "${SECRETS_ENV}"
    fi
    if grep -q '^DEFECTDOJO_URL=' "${SECRETS_ENV}" 2>/dev/null; then
      sed -i "s|^DEFECTDOJO_URL=.*|DEFECTDOJO_URL=${DD_URL}|" "${SECRETS_ENV}"
    else
      printf 'DEFECTDOJO_URL=%s\n' "${DD_URL}" >> "${SECRETS_ENV}"
    fi
  fi
  export DEFECTDOJO_API_TOKEN="${token}"
  export DEFECTDOJO_URL="${DD_URL}"
}

apply_gateway() {
  log "apply cxado-tls-gateway (DefectDojo NodePort 30808)"
  for f in 10-nginx-config.yaml 20-gateway.yaml; do
    scp -P "${SSH_PORT}" "${ROOT}/deploy/k8s/offline-tls/${f}" "${SSH_HOST}:/tmp/dd-gw-${f}"
    remote "${KCTL} -n cxado-edge apply -f /tmp/dd-gw-${f}"
  done
  remote "${KCTL} -n cxado-edge rollout status deploy/cxado-tls-gateway --timeout=180s" || true
}

main() {
  if [[ "${SKIP_MIRROR}" != true ]]; then
    log "mirror defectdojo images to containerd"
    "${ROOT}/scripts/gitlab/mirror-fabrica-ci-images.sh" --ssh "${SSH_HOST}" \
      || log "WARN: mirror had failures — continuing if images present"
  fi

  ensure_nexus_registry
  ensure_secrets
  apply_base
  wait_postgres

  if [[ "${SKIP_INIT}" != true ]]; then
    run_initializer
  else
    log "skip initializer (--skip-init)"
  fi

  apply_apps
  bootstrap_api
  apply_gateway

  log "done — DefectDojo at ${DD_URL}"
  log "admin UI via gateway: https://${CXADO_NODE_IP}:30808/"
  log "next: ./scripts/gitlab/setup-ci-variables.sh && ./scripts/gitlab/smoke-defectdojo-from-k3s.sh"
}

main "$@"
