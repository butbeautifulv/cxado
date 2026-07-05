#!/usr/bin/env bash
# Tear down cxado stacks (default or lite). Veil kept unless CXADO_STOP_VEIL=1.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE_DIR="$ROOT/deploy/compose"
PROFILE="${CXADO_PROFILE:-default}"

case "$PROFILE" in
  minimal)
    EGRESSORE_COMPOSE="$COMPOSE_DIR/egregore-minimal.yml"
    OBS_COMPOSE="$COMPOSE_DIR/observability-lite.yml"
    ;;
  lite)
    VEIL_COMPOSE="$COMPOSE_DIR/veil-graph-lite.yml"
    EGRESSORE_COMPOSE="$COMPOSE_DIR/egregore-infra-lite.yml"
    OBS_COMPOSE="$COMPOSE_DIR/observability-lite.yml"
    ;;
  *)
    VEIL_COMPOSE="$COMPOSE_DIR/veil-graph.yml"
    EGRESSORE_COMPOSE="$COMPOSE_DIR/egregore-infra.yml"
    OBS_COMPOSE="$COMPOSE_DIR/observability.yml"
    ;;
esac

log() { printf '[cxado-down] %s\n' "$*"; }

log "stopping observability..."
docker compose -f "$OBS_COMPOSE" down 2>/dev/null || true
docker compose -f "$COMPOSE_DIR/observability.yml" down 2>/dev/null || true
docker compose -f "$COMPOSE_DIR/observability-lite.yml" down 2>/dev/null || true
docker compose -f "$ROOT/projects/egregore/deploy/observability/docker-compose.yml" down 2>/dev/null || true

log "stopping egregore infra..."
docker compose -f "$EGRESSORE_COMPOSE" down 2>/dev/null || true
docker compose -f "$COMPOSE_DIR/egregore-infra.yml" down 2>/dev/null || true
docker compose -f "$COMPOSE_DIR/egregore-infra-lite.yml" down 2>/dev/null || true
docker compose -f "$COMPOSE_DIR/egregore-minimal.yml" down 2>/dev/null || true

if [[ "${CXADO_STOP_VEIL:-0}" == "1" ]]; then
  log "stopping veil graph..."
  docker compose -f "$VEIL_COMPOSE" --profile mcp down 2>/dev/null || true
  docker compose -f "$COMPOSE_DIR/veil-graph.yml" --profile mcp down 2>/dev/null || true
  docker compose -f "$COMPOSE_DIR/veil-graph-lite.yml" --profile mcp down 2>/dev/null || true
  docker compose -f "$ROOT/projects/veil/docker-compose.yml" \
    -f "$ROOT/projects/veil/deploy/knowledge/compose.neo4j-publish.yml" \
    --profile mcp down 2>/dev/null || true
else
  log "keeping veil graph running (set CXADO_STOP_VEIL=1 to stop)"
fi

if [[ "${CXADO_STOP_LANGFUSE:-0}" == "1" ]]; then
  log "stopping langfuse..."
  docker compose -f "$COMPOSE_DIR/langfuse.yml" down 2>/dev/null || true
  docker compose -f "$ROOT/projects/egregore/deploy/langfuse/docker-compose.yml" down 2>/dev/null || true
fi

log "done"
