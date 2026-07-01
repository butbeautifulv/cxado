#!/usr/bin/env bash
# Bring up cxado stack (default or lite via CXADO_PROFILE).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE_DIR="$ROOT/deploy/compose"
NETWORK="${CXADO_NETWORK:-cxado-net}"
PROFILE="${CXADO_PROFILE:-default}"

if [[ -f "$ROOT/deploy/profiles/${PROFILE}.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT/deploy/profiles/${PROFILE}.env"
  set +a
fi

case "$PROFILE" in
  lite)
    VEIL_COMPOSE="$COMPOSE_DIR/veil-graph-lite.yml"
    EGRESSORE_COMPOSE="$COMPOSE_DIR/egregore-infra-lite.yml"
    OBS_COMPOSE="$COMPOSE_DIR/observability-lite.yml"
    PROFILE_LABEL="cxado-lite"
    ;;
  *)
    VEIL_COMPOSE="$COMPOSE_DIR/veil-graph.yml"
    EGRESSORE_COMPOSE="$COMPOSE_DIR/egregore-infra.yml"
    OBS_COMPOSE="$COMPOSE_DIR/observability.yml"
    PROFILE_LABEL="cxado-default"
    ;;
esac

log() { printf '[cxado-up] %s\n' "$*"; }

port_in_use() {
  local port="$1"
  ss -ltn 2>/dev/null | grep -q ":${port} " || netstat -ltn 2>/dev/null | grep -q ":${port} "
}

stop_legacy_observability() {
  if docker ps -a --format '{{.Names}}' | grep -qE '^observability-'; then
    log "stopping legacy egregore observability..."
    docker compose -f "$ROOT/projects/egregore/deploy/observability/docker-compose.yml" down 2>/dev/null || true
  fi
}

stop_legacy_egregore_infra() {
  if docker ps -a --format '{{.Names}}' | grep -qE '^egregore-(postgres|redis|qdrant)-'; then
    log "stopping legacy egregore infra containers..."
    docker compose -f "$ROOT/projects/egregore/docker-compose.yml" stop postgres redis qdrant 2>/dev/null || true
    docker rm -f egregore-postgres-1 egregore-redis-1 egregore-qdrant-1 2>/dev/null || true
  fi
}

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  log "creating network $NETWORK"
  docker network create "$NETWORK" >/dev/null
else
  log "network $NETWORK exists"
fi

log "profile: $PROFILE_LABEL"

log "starting veil graph (neo4j, api, mcp)..."
if curl -sf -m 3 "http://localhost:8090/health" >/dev/null 2>&1; then
  log "veil-api already healthy on :8090 — skipping veil compose"
else
  if port_in_use 8090; then
    log "WARN: port 8090 busy but veil-api not healthy — check docker ps"
  fi
  docker compose -f "$VEIL_COMPOSE" --profile mcp up -d --build
fi

stop_legacy_egregore_infra
log "starting egregore infra..."
docker compose -f "$EGRESSORE_COMPOSE" up -d

stop_legacy_observability
log "starting observability..."
docker compose -f "$OBS_COMPOSE" up -d

if [[ "${CXADO_LANGFUSE:-0}" == "1" ]]; then
  log "starting langfuse (optional)..."
  docker compose -f "$COMPOSE_DIR/langfuse.yml" up -d
fi

wait_http() {
  local name="$1" url="$2" tries="${3:-60}"
  local i=0
  until curl -sf -m 3 "$url" >/dev/null 2>&1; do
    i=$((i + 1))
    if [[ $i -ge $tries ]]; then
      log "WARN: $name not healthy at $url after ${tries} attempts"
      return 1
    fi
    sleep 2
  done
  log "$name ok ($url)"
}

wait_http "veil-api" "http://localhost:8090/health" 90 || true
wait_http "veil-mcp" "http://localhost:8091/health" 90 || true
wait_http "grafana" "http://localhost:3002/api/health" 30 || true
wait_http "prometheus" "http://localhost:9091/-/healthy" 30 || true
if [[ "${CXADO_LANGFUSE:-0}" == "1" ]]; then
  wait_http "langfuse" "http://localhost:3001/api/public/health" 60 || true
fi

if docker compose -f "$EGRESSORE_COMPOSE" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
  log "egregore postgres ok"
else
  log "WARN: postgres not ready"
fi

echo ""
echo "$PROFILE_LABEL stack is up."
echo "  veil-api:    http://localhost:8090/health"
echo "  veil-mcp:    http://localhost:8091/health"
echo "  grafana:     http://localhost:3002  (admin/admin)"
echo "  overview:    http://localhost:3002/d/cxado-overview"
echo "  prometheus:  http://localhost:9091/targets"
if [[ "${CXADO_LANGFUSE:-0}" == "1" ]]; then
  echo "  langfuse:    http://localhost:3001"
fi
if [[ "$PROFILE" == lite ]]; then
  echo "  lite:        no Tempo, 1 worker recommended, Qdrant + Langfuse included"
  echo "Next: WORKER_REPLICAS=1 make -C projects/egregore dev"
else
  echo "Next: make -C projects/egregore dev"
fi
