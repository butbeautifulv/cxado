#!/usr/bin/env bash
# End-to-end offline deployment onto the target k3s node via SSH-forward.
#
# This script runs on the laptop/workspace machine.
#
# Usage:
#   CXADO_OFFLINE_TAG=offline-YYYYMMDD \
#   POSTGRES_PASSWORD=... REDIS_PASSWORD=... NEO4J_PASSWORD=... \
#   CXADO_OFFLINE_SUDO_PW=... \
#   ./scripts/k8s/k3s-deploy-cxado-offline.sh [--with-veil]
#
# Defaults (see scripts/k8s/cxado-offline-env.sh):
#   ssh bbv-p30-wifi  -> 192.168.0.133 (direct USB WiFi on P30)
# Corp NAT alternative: CXADO_OFFLINE_SSH_HOST=bbv-p30-k44 CXADO_OFFLINE_SSH_PORT=22012
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

TAG="${CXADO_OFFLINE_TAG:-offline-$(date +%Y%m%d)}"
SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
SUDO_PW="${CXADO_OFFLINE_SUDO_PW:-}"

SECRETS_ENV_FILE="${CXADO_SECRETS_ENV_FILE:-${ROOT}/deploy/.secrets/cxado-k3s.env}"

POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
NEO4J_PASSWORD="${NEO4J_PASSWORD:-}"

LOG_FILE="${CXADO_DEPLOY_LOG:-${ROOT}/deploy_logs/cxado_k3s_10.8.185.15_$(date +%Y-%m-%d).md}"

WITH_VEIL=0
for arg in "$@"; do
  case "$arg" in
    --with-veil) WITH_VEIL=1 ;;
  esac
done

log() { printf '[deploy] %s\n' "$*"; }

run() {
  # Run a command and tee to log
  local cmd="$1"
  {
    echo ""
    echo "### $(date -Is)"
    echo "\`\`\`bash"
    echo "$cmd"
    echo "\`\`\`"
    echo ""
  } >>"$LOG_FILE"
  bash -lc "$cmd" 2>&1 | tee -a "$LOG_FILE"
}

run_public() {
  # Like run(), but logs only the public (redacted) command.
  local public_cmd="$1"
  local real_cmd="$2"
  {
    echo ""
    echo "### $(date -Is)"
    echo "\`\`\`bash"
    echo "$public_cmd"
    echo "\`\`\`"
    echo ""
  } >>"$LOG_FILE"
  bash -lc "$real_cmd" 2>&1 | tee -a "$LOG_FILE"
}

remote_sudo() {
  local rcmd="$1"
  if [[ -n "$SUDO_PW" ]]; then
    ssh -p "$SSH_PORT" "$SSH_HOST" "printf '%s\n' '$SUDO_PW' | sudo -S -p '' bash -lc $(printf %q "$rcmd")"
  else
    ssh -p "$SSH_PORT" "$SSH_HOST" "sudo bash -lc $(printf %q "$rcmd")"
  fi
}

remote() {
  local rcmd="$1"
  ssh -p "$SSH_PORT" "$SSH_HOST" "bash -lc $(printf %q "$rcmd")"
}

main() {
  mkdir -p "${ROOT}/deploy_logs"
  {
    echo "# cxado k3s offline deploy log"
    echo ""
    echo "- date: $(date -Is)"
    echo "- tag: ${TAG}"
    echo "- ssh: ${SSH_HOST}:${SSH_PORT}"
    echo ""
  } >"$LOG_FILE"

  log "log file: $LOG_FILE"

  if [[ -f "${SECRETS_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    set -a; source "${SECRETS_ENV_FILE}"; set +a
  fi

  if [[ -z "${POSTGRES_PASSWORD:-}" || -z "${REDIS_PASSWORD:-}" || -z "${NEO4J_PASSWORD:-}" ]]; then
    echo "missing required secrets env vars: POSTGRES_PASSWORD / REDIS_PASSWORD / NEO4J_PASSWORD" >&2
    echo "provide them via env or ${SECRETS_ENV_FILE}" >&2
    exit 2
  fi
  if [[ -z "${CXADO_OFFLINE_SUDO_PW:-$SUDO_PW}" ]]; then
    echo "missing sudo password: set CXADO_OFFLINE_SUDO_PW (via env or ${SECRETS_ENV_FILE})" >&2
    exit 2
  fi

  run_public \
    "CXADO_OFFLINE_TAG='${TAG}' CXADO_OFFLINE_SSH_HOST='${SSH_HOST}' CXADO_OFFLINE_SSH_PORT='${SSH_PORT}' CXADO_OFFLINE_SUDO_PW='***REDACTED***' ./scripts/k8s/k3s-offline-bundle-min.sh" \
    "CXADO_OFFLINE_TAG='${TAG}' CXADO_OFFLINE_SSH_HOST='${SSH_HOST}' CXADO_OFFLINE_SSH_PORT='${SSH_PORT}' CXADO_OFFLINE_SUDO_PW='${CXADO_OFFLINE_SUDO_PW:-$SUDO_PW}' ./scripts/k8s/k3s-offline-bundle-min.sh"

  run_public \
    "CXADO_OFFLINE_TAG='${TAG}' CXADO_OFFLINE_SSH_HOST='${SSH_HOST}' CXADO_OFFLINE_SSH_PORT='${SSH_PORT}' CXADO_OFFLINE_SUDO_PW='***REDACTED***' ./scripts/k8s/k3s-offline-bundle-egregore.sh" \
    "CXADO_OFFLINE_TAG='${TAG}' CXADO_OFFLINE_SSH_HOST='${SSH_HOST}' CXADO_OFFLINE_SSH_PORT='${SSH_PORT}' CXADO_OFFLINE_SUDO_PW='${CXADO_OFFLINE_SUDO_PW:-$SUDO_PW}' ./scripts/k8s/k3s-offline-bundle-egregore.sh"

  run_public \
    "CXADO_OFFLINE_SSH_HOST='${SSH_HOST}' CXADO_OFFLINE_SSH_PORT='${SSH_PORT}' CXADO_OFFLINE_SUDO_PW='***REDACTED***' ./scripts/k8s/k3s-offline-bundle-obs.sh" \
    "CXADO_OFFLINE_SSH_HOST='${SSH_HOST}' CXADO_OFFLINE_SSH_PORT='${SSH_PORT}' CXADO_OFFLINE_SUDO_PW='${CXADO_OFFLINE_SUDO_PW:-$SUDO_PW}' ./scripts/k8s/k3s-offline-bundle-obs.sh"

  # One-time kubeconfig setup so we can run kubectl/helm without sudo afterwards.
  run_public \
    "ssh ... 'sudo install /home/bbv/.kube/config (redacted pw)'" \
    "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"printf '%s\\n' '${CXADO_OFFLINE_SUDO_PW:-$SUDO_PW}' | sudo -S -p '' bash -lc 'install -d -m 700 /home/bbv/.kube && cp /etc/rancher/k3s/k3s.yaml /home/bbv/.kube/config && chown -R bbv:bbv /home/bbv/.kube && chmod 600 /home/bbv/.kube/config'\""

  KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
  HELM="KUBECONFIG=/home/bbv/.kube/config helm"

  log "apply namespaces"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/cxado-offline/00-namespaces.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/obs-offline/00-namespace.yaml'"

  log "create/refresh secrets (cxado-data)"
  run_public \
    "kubectl create secret cxado-credentials (values redacted)" \
    "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-data delete secret cxado-credentials 2>/dev/null || true; ${KCTL} -n cxado-data create secret generic cxado-credentials --from-literal=postgres-password='${POSTGRES_PASSWORD}' --from-literal=redis-password='${REDIS_PASSWORD}' --from-literal=neo4j-password='${NEO4J_PASSWORD}' --from-literal=neo4j-auth='neo4j/${NEO4J_PASSWORD}'\""

  log "apply data-plane manifests"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/cxado-offline/10-postgres.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/cxado-offline/11-redis.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/cxado-offline/14-redpanda.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-data rollout status deploy/redpanda --timeout=300s\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-data delete job redpanda-topics-init --ignore-not-found\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/cxado-offline/15-redpanda-topics-job.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-data wait --for=condition=complete job/redpanda-topics-init --timeout=300s\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/cxado-offline/12-qdrant.yaml'"

  # neo4j already exists in veil-offline namespace in prior steps; cxado-data neo4j is optional for egregore,
  # but we apply it to match the plan.
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/cxado-offline/13-neo4j.yaml'"

  if [[ "$WITH_VEIL" -eq 1 ]]; then
    log "deploy veil (graph-only) before egregore"
    run "VEIL_OFFLINE_TAG='${TAG}' VEIL_OFFLINE_SSH_HOST='${SSH_HOST}' VEIL_OFFLINE_SSH_PORT='${SSH_PORT}' '${ROOT}/scripts/k8s/k3s-deploy-veil-offline.sh' --no-smoke"
  fi

  log "observability configmaps + deploy"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' 'bash -lc \"rm -rf /tmp/cxado-obs-bundle && mkdir -p /tmp/cxado-obs-bundle/k8s /tmp/cxado-obs-bundle/observability\"'"
  run "rsync -a -e \"ssh -p ${SSH_PORT}\" \"${ROOT}/deploy/k8s/obs-offline/prometheus-k3s.yml\" \"${SSH_HOST}:/tmp/cxado-obs-bundle/k8s/\""
  run "rsync -a -e \"ssh -p ${SSH_PORT}\" \"${ROOT}/deploy/observability/\" \"${SSH_HOST}:/tmp/cxado-obs-bundle/observability/\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' 'bash -lc \"cat >/tmp/obs-create-configmaps.sh\"' < '${ROOT}/scripts/k8s/obs-create-configmaps.sh'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' 'bash -lc \"chmod +x /tmp/obs-create-configmaps.sh\"'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"CXADO_OBS_SRC=/tmp/cxado-obs-bundle KUBECONFIG=/home/bbv/.kube/config KUBECTL='k3s kubectl' /tmp/obs-create-configmaps.sh\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/obs-offline/10-prometheus.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/obs-offline/20-grafana.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/obs-offline/30-tempo.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/obs-offline/31-loki.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} apply -f -\" < '${ROOT}/deploy/k8s/obs-offline/32-promtail.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-obs rollout restart deploy/prometheus deploy/grafana deploy/tempo deploy/loki || true\""

  log "install egregore via helm"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' 'cat >/tmp/values-egregore-offline.yaml' < '${ROOT}/deploy/k8s/cxado-offline/values-egregore-offline.yaml'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"sed -i 's/__CXADO_OFFLINE_TAG__/${TAG}/g' /tmp/values-egregore-offline.yaml\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} create ns cxado-app 2>/dev/null || true\""
  run "rsync -a -e \"ssh -p ${SSH_PORT}\" \"${ROOT}/projects/egregore/deploy/helm/egregore\" \"${SSH_HOST}:/tmp/egregore-helm\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${HELM} upgrade --install egregore /tmp/egregore-helm/egregore -n cxado-app -f /tmp/values-egregore-offline.yaml --set image.tag='${TAG}' --set ui.image.tag='${TAG}' --set postgres.password='${POSTGRES_PASSWORD}' --set redis.password='${REDIS_PASSWORD}' --wait --timeout 10m\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-app rollout status deploy/egregore-api --timeout=300s\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-app rollout status deploy/egregore-worker --timeout=300s\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} -n cxado-app rollout status deploy/egregore-ui --timeout=300s\""

  log "apply tls gateway (https nodeports) and show status"
  run "'${ROOT}/scripts/k8s/offline-tls-apply.sh'"
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} get pods -A -o wide\""
  run "ssh -p '${SSH_PORT}' '${SSH_HOST}' \"${KCTL} get svc -A | rg -n \\\"NodePort|egregore|veil|grafana|prometheus|neo4j\\\" || true\""

  if [[ -x "${ROOT}/scripts/k8s/smoke-test-egregore-obs.sh" ]]; then
    log "observability smoke test"
    run "CXADO_OFFLINE_SSH_HOST='${SSH_HOST}' CXADO_OFFLINE_SSH_PORT='${SSH_PORT}' '${ROOT}/scripts/k8s/smoke-test-egregore-obs.sh' || true"
  fi
}

main "$@"

