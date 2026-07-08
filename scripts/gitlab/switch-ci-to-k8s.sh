#!/usr/bin/env bash
# Switch CI from P30 shell runner to in-cluster kubernetes runner + trigger pipeline.
#
# Usage:
#   ./scripts/gitlab/switch-ci-to-k8s.sh
#   ./scripts/gitlab/switch-ci-to-k8s.sh --skip-sync   # runner only, no git push
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

SKIP_SYNC=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-sync) SKIP_SYNC=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[switch-ci-k8s] %s\n' "$*"; }

log "1/5 pause shell runner (p30-k3s-shell)"
./scripts/gitlab/setup-runner-p30.sh pause

log "2/5 bootstrap kubernetes runner in cxado-ci"
./scripts/gitlab/setup-runner-k8s.sh --ssh bbv-p30-wifi bootstrap

log "3/5 refresh GitLab CI/CD variables"
./scripts/gitlab/setup-ci-variables.sh

if [[ "${SKIP_SYNC}" == false ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    log "4/5 commit CI changes"
    git add .gitlab-ci.yml .gitlab/ config/ CODEOWNERS deploy/ scripts/
    git add -u scripts/gitlab/ci-*.sh 2>/dev/null || true
    git commit -m "$(cat <<'EOF'
Switch cxado CI to Fabrica pipeline with k8s GitLab runner.

Replace shell-runner Kaniko bash jobs with modular YAML (oss-full-enterprise + Kaniko overlay).
Centralize registry URLs in deploy/registry.defaults.env.
EOF
)"
  else
    log "4/5 working tree clean — skip commit"
  fi
  log "5/5 sync to gitlab.svo.aero and trigger pipeline"
  ./scripts/gitlab/sync-monorepo-to-gitlab.sh
  # shellcheck source=deploy/.secrets/cxado-k3s.env
  source "${ROOT}/deploy/.secrets/cxado-k3s.env"
  ssh bbv-p30-wifi "curl -sk --request POST \
    --header 'PRIVATE-TOKEN: ${GITLAB_PAT_RUNNER}' \
    '${GITLAB_URL}/api/v4/projects/${GITLAB_PROJECT_ID}/pipeline' \
    -d 'ref=main'" | head -c 500
  echo
else
  log "4/5 skipped sync (--skip-sync)"
  log "5/5 trigger pipeline manually after sync"
fi

log "done — check: https://gitlab.svo.aero/av.popov/cxado/-/pipelines"
