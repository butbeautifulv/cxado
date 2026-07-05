#!/usr/bin/env bash
# Minimal local stack: postgres + redis + Langfuse + Prometheus/Grafana (no veil/kafka/qdrant).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE_DIR="$ROOT/deploy/compose"
NETWORK="${CXADO_NETWORK:-cxado-net}"
PROFILE="${CXADO_PROFILE:-minimal}"
SECRETS_FILE="$ROOT/deploy/.secrets/egregore-local.env"

if [[ -f "$ROOT/deploy/profiles/${PROFILE}.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT/deploy/profiles/${PROFILE}.env"
  set +a
fi

EGRESSORE_COMPOSE="$COMPOSE_DIR/egregore-minimal.yml"
OBS_COMPOSE="$COMPOSE_DIR/observability-lite.yml"
LF_BOOTSTRAP="$ROOT/projects/egregore/scripts/langfuse-dev-bootstrap.sh"

log() { printf '[cxado-up-minimal] %s\n' "$*"; }

if [[ ! -f "$SECRETS_FILE" ]]; then
  log "WARN: missing $SECRETS_FILE — copy deploy/secrets/egregore-local.env.example and set DEEPSEEK_API_KEY"
elif ! grep -q '^DEEPSEEK_API_KEY=.\+' "$SECRETS_FILE" 2>/dev/null; then
  log "WARN: DEEPSEEK_API_KEY empty in $SECRETS_FILE"
fi

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  log "creating network $NETWORK"
  docker network create "$NETWORK" >/dev/null
fi

log "starting egregore infra (postgres + redis)..."
docker compose -f "$EGRESSORE_COMPOSE" up -d

log "starting observability (prometheus + grafana)..."
docker compose -f "$OBS_COMPOSE" up -d

log "bootstrapping Langfuse (LLM traces)..."
chmod +x "$LF_BOOTSTRAP"
"$LF_BOOTSTRAP"

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

wait_http "grafana" "http://localhost:3002/api/health" 30 || true
wait_http "prometheus" "http://localhost:9091/-/healthy" 30 || true
wait_http "langfuse" "http://localhost:3001/api/public/health" 90 || true

if docker compose -f "$EGRESSORE_COMPOSE" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
  log "postgres ok"
else
  log "WARN: postgres not ready"
fi

echo ""
echo "cxado-minimal stack is up (no veil, no kafka, no qdrant)."
echo "  langfuse:    http://localhost:3001"
if [[ -f "$ROOT/projects/egregore/deploy/langfuse/.env" ]]; then
  pk=$(grep -E '^LANGFUSE_INIT_PROJECT_PUBLIC_KEY=' "$ROOT/projects/egregore/deploy/langfuse/.env" | cut -d= -f2- || true)
  if [[ -n "$pk" ]]; then
    echo "  langfuse keys: see projects/egregore/deploy/langfuse/.env (LANGFUSE_INIT_PROJECT_*)"
  fi
fi
echo "  grafana:     http://localhost:3002  (admin/admin)"
echo "  prometheus:  http://localhost:9091/targets"
echo "  egregore:    http://localhost:8080/health  (after dev)"
echo ""
echo "Next:"
echo "  make cxado-up-veil                    # veil graph + MCP for tool enrichment"
echo "  WORKER_REPLICAS=1 make -C projects/egregore dev"
echo ""
echo "Smoke:"
echo "  cd projects/egregore && uv run egregore agent consultant -i 'ping'"
