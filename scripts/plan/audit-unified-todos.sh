#!/usr/bin/env bash
# Verify all source plan todos are present in egregore_unified_masterplan.md frontmatter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UNIFIED="${ROOT}/docs/egregore_unified_masterplan.md"
DEPLOY="${ROOT}/.cursor/plans/reliable_k3s_egregore_deploy_5ce71772.plan.md"
PLATFORM="${ROOT}/.cursor/plans/egregore_platform_masterplan_97ac326c.plan.md"
DS="${ROOT}/.cursor/plans/egregore-datasources-rbac_d4df7472.plan.md"

extract_ids() {
  local file="$1"
  rg '^  - id: ' "$file" | sed 's/^  - id: //' | sort -u
}

extract_source_ids() {
  local file="$1"
  rg 'source_id: ' "$file" | sed 's/.*source_id: //' | tr -d '"' | sort -u
}

deploy_ids="$(extract_ids "$DEPLOY")"
plat_ids="$(extract_ids "$PLATFORM")"
ds_ids="$(extract_ids "$DS")"
unified_source_ids="$(extract_source_ids "$UNIFIED")"

missing=0
check_missing() {
  local label="$1"
  local ids="$2"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! echo "$unified_source_ids" | grep -qxF "$id"; then
      echo "MISSING source_id: $id (from $label)"
      missing=$((missing + 1))
    fi
  done <<< "$ids"
}

check_missing deploy "$deploy_ids"
check_missing platform "$plat_ids"
check_missing datasources "$ds_ids"

# New stream todos
for id in que-01 que-02 que-03 que-04 que-05 que-06 que-07 que-08 que-09 que-10 \
  cat-01 cat-02 cat-03 cat-04 cat-05 cat-06 cat-07 cat-08 cat-09 \
  py-01 py-02 py-03 py-04 py-05 py-06 py-07 py-08 py-09 py-10 py-11 \
  py-12 py-13 py-14 py-15 py-16 py-17 py-18 py-19 py-20 py-21 py-22 \
  dep-kafka-max-poll; do
  if ! echo "$unified_source_ids" | grep -qxF "$id"; then
    echo "MISSING new source_id: $id"
    missing=$((missing + 1))
  fi
done

total="$(rg -c '^  - id: unified-' "$UNIFIED" || true)"
echo "---"
echo "unified todos: ${total}"
echo "deploy source: $(echo "$deploy_ids" | wc -l)"
echo "platform source: $(echo "$plat_ids" | wc -l)"
echo "datasources source: $(echo "$ds_ids" | wc -l)"
echo "expected 328 (86 deploy + 151 platform + 49 datasources + 42 new)"

if [[ "$missing" -gt 0 ]]; then
  echo "FAIL: $missing missing source_id entries"
  exit 1
fi
echo "PASS: all source todos mapped in unified plan"
