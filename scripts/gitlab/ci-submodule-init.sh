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
GITLAB_HOST="${CI_SERVER_HOST:-gitlab.svo.aero}"
SUBMODULES="${CI_SUBMODULES:-projects/egregore}"

submodule_url() {
  local repo="$1"
  if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
    printf 'https://gitlab-ci-token:%s@%s/av.popov/%s.git' "${CI_JOB_TOKEN}" "${GITLAB_HOST}" "${repo}"
  else
    printf '%s/%s.git' "${PREFIX}" "${repo}"
  fi
}

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
  gitlab_url="$(submodule_url "${repo}")"
  git config "submodule.${path}.url" "${gitlab_url}"
  echo "[ci-submodule] ${path} -> gitlab.svo.aero/av.popov/${repo}.git"
  git submodule sync --recursive "${path}"
  git -c protocol.file.allow=always submodule update --init --depth 1 "${path}"
done

for path in ${SUBMODULES}; do
  if [[ ! -d "${path}" ]]; then
    echo "[ci-submodule] checkout failed: ${path}" >&2
    exit 2
  fi
done

echo "[ci-submodule] ok"
