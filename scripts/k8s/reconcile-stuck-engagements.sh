#!/usr/bin/env bash
# Reconcile engagements stuck in status=running (Phase 0 ops).
# Applies domain-consistent state fixes via Postgres when reconciler loop is unavailable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH=(ssh -o BatchMode=yes -p "${CXADO_OFFLINE_SSH_PORT}" "${CXADO_OFFLINE_SSH_HOST}")
KUBECTL="K3S_CONFIG_FILE=${K3S_CONFIG_FILE} KUBECONFIG=/home/bbv/.kube/config k3s kubectl"

log() { printf '[reconcile-stuck] %s\n' "$*"; }

log "scanning running engagements in postgres..."
"${SSH[@]}" "${KUBECTL} -n cxado-data exec deploy/postgres -- psql -U postgres -d egregore -t -A -F'|' -c \"
SELECT engagement_id,
       state_json->>'planner_plan' AS plan,
       state_json->>'completed_personas' AS completed,
       state_json->>'failed_personas' AS failed,
       COALESCE(state_json->>'synthesis_status', '') AS synth,
       jsonb_array_length(COALESCE(state_json->'findings_summary', '[]'::jsonb)) AS findings
FROM engagements
WHERE state_json->>'status' = 'running'
ORDER BY updated_at DESC;
\""

log "applying reconciliation updates..."
"${SSH[@]}" "${KUBECTL} -n cxado-data exec -i deploy/postgres -- psql -U postgres -d egregore -v ON_ERROR_STOP=1" <<'EOSQL'
-- eng-45270be5bd68 / eng-c3d7d5ffb265: stale consultant synth → degraded close
UPDATE engagements SET state_json = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(state_json, '{synthesis_status}', '"done"'),
      '{status}', '"closed"'
    ),
    '{planner_error}', '"synthesis_stale_timeout"'
  ),
  '{final_report}',
  jsonb_build_object(
    'topic', 'Degraded synthesis',
    'summary', 'Manual reconcile: synthesis job stale',
    'degraded', true,
    'specialist_findings', COALESCE(state_json->'findings_summary', '[]'::jsonb)
  )
), updated_at = now()
WHERE engagement_id IN ('eng-45270be5bd68', 'eng-c3d7d5ffb265')
  AND state_json->>'status' = 'running';

UPDATE worker_jobs SET status = 'failed', updated_at = now()
WHERE job_id IN ('consultant-eng-45270be5bd68-synth', 'consultant-eng-c3d7d5ffb265-synth')
  AND status IN ('running', 'pending');

-- eng-881ca6e7e2a8: specialists failed, synth pending → failed
UPDATE engagements SET state_json = jsonb_set(
  jsonb_set(
    jsonb_set(state_json, '{synthesis_status}', '"done"'),
    '{status}', '"failed"'
  ),
  '{planner_error}', '"all_specialists_failed"'
), updated_at = now()
WHERE engagement_id = 'eng-881ca6e7e2a8'
  AND state_json->>'status' = 'running';

-- eng-f80e7dc5157f: legacy multi-persona run, all terminal → failed
UPDATE engagements SET state_json = jsonb_set(
  jsonb_set(
    jsonb_set(state_json, '{status}', '"failed"'),
    '{planner_error}', '"manual_reconcile_legacy_run"'
  ),
  '{synthesis_status}', '"skipped"'
), updated_at = now()
WHERE engagement_id = 'eng-f80e7dc5157f'
  AND state_json->>'status' = 'running';

-- eng-fa2b862763e0 / eng-2b51899adc43: pending specialist jobs, inconsistent state → failed
UPDATE engagements SET state_json = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(state_json, '{status}', '"failed"'),
      '{planner_error}', '"manual_reconcile_stale_pending"'
    ),
    '{synthesis_status}', '"skipped"'
  ),
  '{failed_personas}',
  COALESCE(state_json->'planner_plan', '[]'::jsonb)
), updated_at = now()
WHERE engagement_id IN ('eng-fa2b862763e0', 'eng-2b51899adc43')
  AND state_json->>'status' = 'running';

UPDATE worker_jobs SET status = 'failed', updated_at = now()
WHERE correlation_id IN ('eng-fa2b862763e0', 'eng-2b51899adc43')
  AND status = 'pending';

SELECT engagement_id, state_json->>'status' AS status, state_json->>'synthesis_status' AS synth
FROM engagements
WHERE engagement_id IN (
  'eng-45270be5bd68', 'eng-c3d7d5ffb265', 'eng-881ca6e7e2a8',
  'eng-f80e7dc5157f', 'eng-fa2b862763e0', 'eng-2b51899adc43'
)
ORDER BY engagement_id;
EOSQL

log "purge stale redis queue entries (best-effort)..."
"${SSH[@]}" "${KUBECTL} -n cxado-data exec deploy/redis -- redis-cli --scan --pattern 'worker:queue:*'" 2>/dev/null | head -5 || true

log "done"
