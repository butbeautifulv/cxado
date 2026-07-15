#!/usr/bin/env bash
# Shared Git remote helpers — GitHub is the default dev upstream; GitLab is ephemeral (corp sync only).

GITHUB_MONOREPO_URL="${GITHUB_MONOREPO_URL:-https://github.com/butbeautifulv/cxado.git}"
GITLAB_MONOREPO_URL="${GITLAB_MONOREPO_URL:-git@gitlab.svo.aero:av.popov/cxado.git}"
GITLAB_REMOTE_NAME="${GITLAB_REMOTE_NAME:-gitlab}"
GITHUB_REMOTE_NAME="${GITHUB_REMOTE_NAME:-origin}"

is_gitlab_url() {
  [[ "$1" == *gitlab.svo.aero* ]]
}

github_url_for_submodule_path() {
  local root="$1" path="$2"
  local modules_file="${3:-${root}/.gitmodules.github}"
  git -C "${root}" config -f "${modules_file}" --get "submodule.${path}.url" 2>/dev/null || return 1
}

gitlab_ssh_for_submodule_path() {
  local root="$1" path="$2"
  local modules_file="${3:-${root}/.gitmodules.gitlab}"
  git -C "${root}" config -f "${modules_file}" --get "submodule.${path}.url" 2>/dev/null || return 1
}

repo_name_for_submodule_path() {
  local url
  url="$(github_url_for_submodule_path "$@")" || return 1
  basename "${url}" .git
}

ensure_origin_github_in_repo() {
  local repo_dir="$1" github_url="$2" branch="${3:-main}"
  local current origin_url

  [[ -d "${repo_dir}/.git" || -f "${repo_dir}/.git" ]] || return 0

  cd "${repo_dir}"

  if git remote | grep -qx "${GITHUB_REMOTE_NAME}"; then
    current="$(git remote get-url "${GITHUB_REMOTE_NAME}")"
    if is_gitlab_url "${current}"; then
      git remote set-url "${GITHUB_REMOTE_NAME}" "${github_url}"
    fi
  else
    git remote add "${GITHUB_REMOTE_NAME}" "${github_url}"
  fi

  origin_url="$(git remote get-url "${GITHUB_REMOTE_NAME}")"
  if [[ "${origin_url}" != "${github_url}" ]]; then
    git remote set-url "${GITHUB_REMOTE_NAME}" "${github_url}"
  fi

  if git remote | grep -qx "${GITLAB_REMOTE_NAME}"; then
    git remote remove "${GITLAB_REMOTE_NAME}"
  fi

  if git show-ref --verify --quiet "refs/remotes/${GITHUB_REMOTE_NAME}/${branch}"; then
    git branch --set-upstream-to="${GITHUB_REMOTE_NAME}/${branch}" "${branch}" 2>/dev/null || true
  elif git show-ref --verify --quiet "refs/heads/${branch}"; then
    git branch --set-upstream-to="${GITHUB_REMOTE_NAME}/${branch}" "${branch}" 2>/dev/null || true
  fi

  cd - >/dev/null
}

ensure_gitlab_remote_ephemeral() {
  local repo_dir="$1" gitlab_url="$2"
  cd "${repo_dir}"
  git remote remove "${GITLAB_REMOTE_NAME}" 2>/dev/null || true
  git remote add "${GITLAB_REMOTE_NAME}" "${gitlab_url}"
  cd - >/dev/null
}

remove_gitlab_remote_in_repo() {
  local repo_dir="$1"
  [[ -d "${repo_dir}/.git" || -f "${repo_dir}/.git" ]] || return 0
  cd "${repo_dir}"
  git remote remove "${GITLAB_REMOTE_NAME}" 2>/dev/null || true
  cd - >/dev/null
}

list_submodule_paths() {
  local root="$1"
  git -C "${root}" config -f "${root}/.gitmodules.github" --get-regexp '^submodule\..*\.path$' \
    | awk '{print $2}'
}

restore_github_gitmodules() {
  local root="$1"
  local github="${root}/.gitmodules.github"
  [[ -f "${github}" ]] || return 0
  cp "${github}" "${root}/.gitmodules"
  git -C "${root}" submodule sync --recursive 2>/dev/null || true
}
