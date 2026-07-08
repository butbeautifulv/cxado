#!/usr/bin/env bash
# Discover all mirror repo names from .gitmodules.gitlab files (root + nested).
discover_mirror_repos() {
  local root="$1" f
  while IFS= read -r f; do
    git config -f "${f}" --get-regexp '^submodule\..*\.url$' 2>/dev/null \
      | awk '{print $2}' | while read -r url; do basename "${url}" .git; done
  done < <(find "${root}" \( -path "${root}/.git" -o -path "${root}/.git/*" \) -prune \
    -o -name .gitmodules.gitlab -print 2>/dev/null)
}
