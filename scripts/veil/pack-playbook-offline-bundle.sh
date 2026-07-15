#!/usr/bin/env bash
# Build Veil playbook offline bundle: metadata + Bleve search index + corpus SKILL.md.
#
# Usage:
#   ./scripts/veil/pack-playbook-offline-bundle.sh
#   VEIL_PLAYBOOK_BUNDLE=/tmp/veil_playbooks_offline.tgz ./scripts/veil/pack-playbook-offline-bundle.sh
#
# Output layout (extract under /var/lib/veil/playbooks):
#   docs/skills-index/{cyber-skills.json, procedures-index.json, playbook-search.bleve, ...}
#   corpus/anthropic-cybersecurity-skills/skills/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VEIL="${ROOT}/projects/veil"
OUT="${VEIL_PLAYBOOK_BUNDLE:-/tmp/veil_playbooks_offline.tgz}"
STAGING="$(mktemp -d)"

log() { printf '[pack-playbook-offline] %s\n' "$*"; }
die() { printf '[pack-playbook-offline] ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() { rm -rf "${STAGING}"; }
trap cleanup EXIT

log "build indexes in ${VEIL}"
(
  cd "${VEIL}"
  make skills-index procedures-index search-index
)

INDEX_SRC="${VEIL}/docs/skills-index"
CORPUS_SRC="${VEIL}/corpus/anthropic-cybersecurity-skills/skills"

for req in \
  "${INDEX_SRC}/cyber-skills.json" \
  "${INDEX_SRC}/procedures-index.json" \
  "${INDEX_SRC}/playbook-search.bleve" \
  "${CORPUS_SRC}"; do
  [[ -e "${req}" ]] || die "missing required artifact: ${req}"
done

log "stage bundle under ${STAGING}"
mkdir -p "${STAGING}/docs/skills-index" "${STAGING}/corpus/anthropic-cybersecurity-skills"
cp -a "${INDEX_SRC}/cyber-skills.json" "${STAGING}/docs/skills-index/"
cp -a "${INDEX_SRC}/procedures-index.json" "${STAGING}/docs/skills-index/"
cp -a "${INDEX_SRC}/playbook-search.bleve" "${STAGING}/docs/skills-index/"
if [[ -f "${INDEX_SRC}/playbook-chunks.jsonl" ]]; then
  cp -a "${INDEX_SRC}/playbook-chunks.jsonl" "${STAGING}/docs/skills-index/"
fi
if [[ -f "${INDEX_SRC}/search-index-manifest.json" ]]; then
  cp -a "${INDEX_SRC}/search-index-manifest.json" "${STAGING}/docs/skills-index/"
fi
cp -a "${CORPUS_SRC}" "${STAGING}/corpus/anthropic-cybersecurity-skills/"

log "pack -> ${OUT}"
tar -C "${STAGING}" -czf "${OUT}" docs corpus
ls -lh "${OUT}"

log "done — bootstrap with:"
log "  ./scripts/veil/bootstrap-skills-index-hostpath.sh ${OUT}"
