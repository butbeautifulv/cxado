#!/usr/bin/env bash
# Init submodules for corp CI — GitLab URLs only, never GitHub.
#
# On gitlab.svo.aero/av.popov/cxado, .gitmodules points to GitLab (via sync script).
# In CI always uses HTTPS + CI_JOB_TOKEN (no SSH / known_hosts).
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

block_github() {
  if [[ -n "${CI_JOB_TOKEN:-}" ]]; then
    git config --global url."https://gitlab-ci-token:${CI_JOB_TOKEN}@${GITLAB_HOST}/av.popov/".insteadOf \
      "https://github.com/butbeautifulv/" || true
    git config --global url."https://gitlab-ci-token:${CI_JOB_TOKEN}@${GITLAB_HOST}/av.popov/".insteadOf \
      "git@github.com:butbeautifulv/" || true
    git config --global url."https://gitlab-ci-token:${CI_JOB_TOKEN}@${GITLAB_HOST}/av.popov/".insteadOf \
      "git@${GITLAB_HOST}:av.popov/" || true
  fi
  git config --global url."https://gitlab.svo.aero/av.popov/".insteadOf \
    "https://github.com/butbeautifulv/" 2>/dev/null || true
}

repo_name_from_url() {
  local url="$1"
  basename "${url}" .git
}

needs_ci_https_url() {
  local url="$1"
  [[ -n "${CI_JOB_TOKEN:-}" ]] && [[ "${url}" != *"gitlab-ci-token:"* ]]
}

if [[ ! -f .gitmodules ]]; then
  echo "no .gitmodules in ${ROOT}" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "[ci-submodule] git not found — install git in job image or .egregore_prepare" >&2
  exit 2
fi

block_github

for path in ${SUBMODULES}; do
  url="$(git config -f .gitmodules --get "submodule.${path}.url" 2>/dev/null || true)"
  if [[ -z "${url}" ]]; then
    echo "[ci-submodule] skip missing path in .gitmodules: ${path}" >&2
    continue
  fi

  repo="$(repo_name_from_url "${url}")"
  gitlab_url="$(submodule_url "${repo}")"

  if [[ "${url}" == *"github.com"* ]] || needs_ci_https_url "${url}"; then
    rm -rf "${path}" ".git/modules/${path}"
    git config -f .gitmodules "submodule.${path}.url" "${gitlab_url}"
    git config "submodule.${path}.url" "${gitlab_url}"
    echo "[ci-submodule] ${path} -> av.popov/${repo} (CI token HTTPS)"
  else
    echo "[ci-submodule] ${path} ok (${url})"
  fi

  git config --unset-all "submodule.${path}.active" 2>/dev/null || true
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
