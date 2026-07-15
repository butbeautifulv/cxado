#!/usr/bin/env bash
# Verify internal markdown links under docs/ (relative paths only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS="${ROOT}/docs"
fail=0

check_link() {
  local src="$1"
  local target="$2"
  local base dir resolved

  base="$(dirname "${src}")"
  if [[ "${target}" == /* ]]; then
    resolved="${ROOT}${target}"
  else
    resolved="$(cd "${base}" && cd "$(dirname "${target}")" 2>/dev/null && pwd)/$(basename "${target}")" || true
    if [[ -z "${resolved}" || "${resolved}" == "/$(basename "${target}")" ]]; then
      resolved="${base}/${target}"
    fi
  fi
  resolved="$(realpath -m "${resolved}" 2>/dev/null || echo "${resolved}")"

  if [[ ! -e "${resolved}" ]]; then
    echo "BROKEN ${src} -> ${target}" >&2
    fail=1
  fi
}

while IFS= read -r -d '' file; do
  while IFS= read -r link; do
    [[ -z "${link}" ]] && continue
    # skip URLs, anchors-only, mailto
    [[ "${link}" =~ ^https?:// ]] && continue
    [[ "${link}" =~ ^mailto: ]] && continue
    local="${link%%#*}"
    [[ -z "${local}" ]] && continue
    check_link "${file}" "${local}"
  done < <(grep -oE '\[[^]]+\]\([^)]+\)' "${file}" | sed -E 's/^\[[^]]+\]\(([^)]+)\)$/\1/' || true)
done < <(find "${DOCS}" -name '*.md' -print0)

if [[ "${fail}" -ne 0 ]]; then
  exit 1
fi
echo "docs link check OK"
