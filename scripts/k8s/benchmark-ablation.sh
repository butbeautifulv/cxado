#!/usr/bin/env bash
# Ablation benchmark wrapper — documents toggles and re-runs B2/B3.
#
# Usage:
#   ABLATION=A0 ./scripts/k8s/benchmark-ablation.sh
#   ABLATION=A1 ./scripts/k8s/benchmark-ablation.sh   # Langfuse eval off (manual in UI)
#   ABLATION=A3 ./scripts/k8s/benchmark-ablation.sh   # trace critic off via helm
#   ABLATION=A7 ./scripts/k8s/benchmark-ablation.sh   # advisory fast-path (code)
#
# A4 (vLLM reasoning off) must be changed on Proxmox vLLM — not automated here.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ABLATION="${ABLATION:-A0}"
OUT_DIR="${BENCHMARK_OUT_DIR:-${ROOT}/deploy_logs}"

mkdir -p "${OUT_DIR}"
LOG="${OUT_DIR}/ablation_${ABLATION}_$(date +%Y%m%d_%H%M%S).md"

{
  echo "# Ablation ${ABLATION}"
  echo "- date: $(date -Is)"
  echo ""
  case "${ABLATION}" in
    A0) echo "Baseline — no changes." ;;
    A1) echo "Disable Langfuse evaluators in UI: Project Settings → Evaluators → pause Helpfulness/Hallucination." ;;
    A2) echo "Set obs.traceBackend=otel in values-egregore-offline.yaml, helm upgrade, restart." ;;
    A3) echo "TRACE_CRITIC_ENABLED=false in values (already set for offline)." ;;
    A4) echo "vLLM: disable Qwen reasoning / set max_reasoning_tokens on GPU VM." ;;
    A5) echo "worker.replicas: 3 in values-egregore-offline.yaml, helm upgrade." ;;
    A7) echo "advisory_fast_path in plan_investigation (deployed in code)." ;;
    *) echo "Unknown ablation ${ABLATION}"; exit 1 ;;
  esac
  echo ""
  echo "## Benchmark run"
} >"${LOG}"

CXADO_OFFLINE_SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}" \
  CXADO_OFFLINE_SSH_PORT="${CXADO_OFFLINE_SSH_PORT:-22}" \
  BENCHMARK_OUT_DIR="${OUT_DIR}" \
  "${ROOT}/scripts/k8s/benchmark-egregore-latency.sh" 2>&1 | tee -a "${LOG}"

echo "" >>"${LOG}"
echo "Log: ${LOG}"
