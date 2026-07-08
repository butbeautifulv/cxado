#!/usr/bin/env bash
# Init selected submodules via GitLab mirrors (GitHub unreachable from corp P30).
#
# Env:
#   CI_SUBMODULE_GITLAB_PREFIX  default: git@gitlab.svo.aero:av.popov
#   CI_SUBMODULES               default: projects/egregore (space-separated paths)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

PREFIX="${CI_SUBMODULE_GITLAB_PREFIX:-git@gitlab.svo.aero:av.popov}"
SUBMODULES="${CI_SUBMODULES:-projects/egregore}"

if [[ ! -f .gitmodules ]]; then
  echo "no .gitmodules in ${ROOT}" >&2
  exit 1
fi

for path in ${SUBMODULES}; do
  url="$(git config -f .gitmodules --get "submodule.${path}.url" 2>/dev/null || true)"
  if [[ -z "${url}" ]]; then
    echo "[ci-submodule] skip missing path in .gitmodules: ${path}" >&2
    continue
  fi
  repo="$(basename "${url}" .git)"
  gitlab_url="${PREFIX}/${repo}.git"
  git config "submodule.${path}.url" "${gitlab_url}"
  echo "[ci-submodule] ${path} -> ${gitlab_url}"
done

git submodule sync --recursive
# shellcheck disable=SC2086
git submodule update --init --depth 1 ${SUBMODULES}

for path in ${SUBMODULES}; do
  if [[ ! -d "${path}" ]]; then
    echo "[ci-submodule] checkout failed: ${path}" >&2
    exit 2
  fi
done

echo "[ci-submodule] ok"
