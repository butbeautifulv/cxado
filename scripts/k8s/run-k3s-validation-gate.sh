#!/usr/bin/env bash
# Phase 9 master validation orchestrator.
#
# Usage:
#   CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/run-k3s-validation-gate.sh
#
# Quick infra-only (no scenarios, no 60m wait):
#   VALIDATION_SKIP_SCENARIOS=1 VALIDATION_SKIP_OBSERVE=1 VALIDATION_SKIP_BENCHMARK=1 \
#     ./scripts/k8s/run-k3s-validation-gate.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

LOG_DIR="${CXADO_ARTIFACTS_DIR}/k3s-validation"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG="${LOG_DIR}/validation_${STAMP}.log"
OBSERVE_SEC="${VALIDATION_OBSERVE_SEC:-300}"
PROMETHEUS_URL="${PROMETHEUS_URL:-https://${CXADO_NODE_IP}:30091}"
WARNINGS=0

mkdir -p "${LOG_DIR}"

run() {
  echo "== $*" | tee -a "${LOG}"
  if "$@" >>"${LOG}" 2>&1; then
    echo "OK  $*" | tee -a "${LOG}"
  else
    echo "FAIL $*" | tee -a "${LOG}"
    return 1
  fi
}

warn() {
  echo "WARN $*" | tee -a "${LOG}"
  WARNINGS=$((WARNINGS + 1))
}

prom_blocking_up() {
  local query='min(up{job=~"egregore-api|veil-mcp|vllm"} == 1)'
  local workers='count(up{job=~"egregore-worker|egregore-dispatcher"} == 1)'
  local out min_up worker_count
  CURL_OPTS=(-fsS)
  [[ "${PROMETHEUS_URL}" == https://* ]] && CURL_OPTS+=(-k)
  out="$(curl "${CURL_OPTS[@]}" -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${query}" 2>/dev/null || true)"
  min_up="$(echo "${out}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=d.get('data',{}).get('result',[])
print(r[0]['value'][1] if r else '0')
" 2>/dev/null || echo 0)"
  out="$(curl "${CURL_OPTS[@]}" -G "${PROMETHEUS_URL}/api/v1/query" --data-urlencode "query=${workers}" 2>/dev/null || true)"
  worker_count="$(echo "${out}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=d.get('data',{}).get('result',[])
print(r[0]['value'][1] if r else '0')
" 2>/dev/null || echo 0)"
  [[ "${min_up}" == "1" && "${worker_count}" -ge 1 ]]
}

log() { printf '[validation-gate] %s\n' "$*" | tee -a "${LOG}"; }

log "log=${LOG}"
log "ssh=${CXADO_OFFLINE_SSH_HOST:-local} observe_sec=${OBSERVE_SEC}"

# --- P9.2 infra gates ---
run "${ROOT}/scripts/k8s/smoke-test-egregore-obs.sh"
run "${ROOT}/scripts/k8s/verify-egregore-rollout.sh"
run "${ROOT}/scripts/k8s/smoke-test-veil-obs.sh"

if prom_blocking_up; then
  log "OK  prometheus blocking targets (api/veil/vllm + dispatcher|worker>=1)"
else
  log "FAIL prometheus blocking targets"
  exit 1
fi

if "${ROOT}/scripts/k8s/smoke-gpu-telemetry.sh" >>"${LOG}" 2>&1; then
  log "OK  smoke-gpu-telemetry"
else
  warn "smoke-gpu-telemetry (recommended Phase 7)"
fi

# --- P9.3 scenarios ---
if [[ "${VALIDATION_SKIP_SCENARIOS:-}" != "1" ]]; then
  run "${ROOT}/scripts/k8s/run-validation-scenarios.sh"
else
  log "SKIP scenarios (VALIDATION_SKIP_SCENARIOS=1)"
fi

# --- P9.4 observation window ---
if [[ "${VALIDATION_SKIP_OBSERVE:-}" != "1" ]]; then
  log "observe ${OBSERVE_SEC}s..."
  sleep "${OBSERVE_SEC}"
else
  log "SKIP observe window"
fi

# Pre snapshot for report if none exists
BASELINE_JSON="${BASELINE_JSON:-}"
if [[ -z "${BASELINE_JSON}" ]]; then
  mapfile -t snaps < <(ls -t "${CXADO_ARTIFACTS_DIR}"/k3s-baseline/baseline-*.json 2>/dev/null || true)
  if [[ "${#snaps[@]}" -ge 2 ]]; then
    BASELINE_JSON="${snaps[-1]}"
  elif [[ "${#snaps[@]}" -eq 1 ]]; then
    BASELINE_JSON="${snaps[0]}"
  fi
fi

if "${ROOT}/scripts/k8s/collect-k3s-baseline.sh" >>"${LOG}" 2>&1; then
  log "OK  collect-k3s-baseline"
else
  warn "collect-k3s-baseline (some critical queries failed — see log)"
fi
AFTER_JSON="$(ls -t "${CXADO_ARTIFACTS_DIR}"/k3s-baseline/baseline-*.json | head -1)"
SCENARIOS_JSON="$(ls -t "${CXADO_ARTIFACTS_DIR}"/k3s-validation/scenarios_*.json 2>/dev/null | head -1 || true)"

if [[ "${VALIDATION_SKIP_BENCHMARK:-}" != "1" && -x "${ROOT}/scripts/k8s/benchmark-egregore-latency.sh" ]]; then
  if BENCHMARK_RUNS=1 "${ROOT}/scripts/k8s/benchmark-egregore-latency.sh" >>"${LOG}" 2>&1; then
    log "OK  benchmark B2 (1 run)"
  else
    warn "benchmark-egregore-latency.sh failed or slow"
  fi
else
  log "SKIP benchmark"
fi

REPORT_PATH="${ROOT}/docs/observability/k3s-bottleneck-after-report.md"
export BASELINE_JSON AFTER_JSON SCENARIOS_JSON PHASE8_DEFERRED=1 REPORT_PATH
"${ROOT}/scripts/k8s/generate-k3s-after-report.sh" | tee -a "${LOG}"
log "report written ${REPORT_PATH}"

if [[ "${WARNINGS}" -gt 0 ]]; then
  log "completed with ${WARNINGS} warning(s) — see report verdict"
fi
log "Validation complete. Log: ${LOG}"
