#!/usr/bin/env bash
# Push current branch to GitHub (public dev upstream). Does not touch GitLab.
#
# Usage:
#   ./scripts/gitlab/push-github.sh
#   ./scripts/gitlab/push-github.sh origin main
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

REMOTE="${1:-origin}"
BRANCH="${2:-$(git branch --show-current)}"

if ! git remote get-url "${REMOTE}" >/dev/null 2>&1; then
  echo "remote '${REMOTE}' not configured" >&2
  exit 2
fi

printf '[push-github] %s -> %s/%s\n' "$(git rev-parse --short HEAD)" "${REMOTE}" "${BRANCH}"
git push "${REMOTE}" "${BRANCH}"

printf '[push-github] done\n'
printf '[push-github] normalize remotes: ./scripts/gitlab/setup-github-remotes.sh\n'
printf '[push-github] corp sync (separate): ./scripts/gitlab/sync-monorepo-to-gitlab.sh\n'
