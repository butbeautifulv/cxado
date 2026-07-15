#!/usr/bin/env bash
# Sync GitHub repo descriptions from docs/github/repo-catalog.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG="${ROOT}/docs/github/repo-catalog.yaml"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI required" >&2
  exit 1
fi

if [[ ! -f "${CATALOG}" ]]; then
  echo "missing ${CATALOG}" >&2
  exit 1
fi

slug=""
description=""
updated=0
skipped=0

flush() {
  if [[ -z "${slug}" ]]; then
    return
  fi
  if [[ -z "${description}" ]]; then
    echo "skip ${slug} (no description)" >&2
    skipped=$((skipped + 1))
    slug=""
    description=""
    return
  fi
  echo "sync ${slug}"
  gh repo edit "${slug}" --description "${description}"
  updated=$((updated + 1))
  slug=""
  description=""
}

while IFS= read -r line || [[ -n "${line}" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  [[ -z "${line}" ]] && continue

  if [[ "${line}" =~ ^-\ slug:\ (.+)$ ]]; then
    flush
    slug="${BASH_REMATCH[1]}"
    description=""
    continue
  fi

  if [[ "${line}" =~ ^description:\ (.+)$ ]] && [[ -n "${slug}" ]]; then
    description="${BASH_REMATCH[1]}"
    # strip optional quotes
    description="${description#\"}"
    description="${description%\"}"
    description="${description#\'}"
    description="${description%\'}"
  fi
done < "${CATALOG}"

flush

echo "done: ${updated} updated, ${skipped} skipped"
