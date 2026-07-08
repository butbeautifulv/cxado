#!/usr/bin/env bash
# Install and register GitLab Runner on P30 (shell executor, user bbv).
#
# Prerequisites:
#   - SSH host bbv-p30-wifi (or CXADO_OFFLINE_SSH_HOST)
#   - deploy/.secrets/cxado-k3s.env with CXADO_OFFLINE_SUDO_PW, GITLAB_URL, GITLAB_PROJECT_ID
#   - GITLAB_RUNNER_TOKEN (glrt-...) from GitLab admin or POST /api/v4/user/runners
#
# Usage:
#   ./scripts/gitlab/setup-runner-p30.sh install          # binary + systemd only
#   ./scripts/gitlab/setup-runner-p30.sh register         # register (needs GITLAB_RUNNER_TOKEN)
#   ./scripts/gitlab/setup-runner-p30.sh create-token   # try API; fails if instance blocks users
#   ./scripts/gitlab/setup-runner-p30.sh status
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
[[ -f "${SECRETS}" ]] && source "${SECRETS}"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST:-bbv-p30-wifi}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.svo.aero}"
PROJECT_ID="${GITLAB_PROJECT_ID:-1938}"
RUNNER_TAGS="${GITLAB_RUNNER_TAGS:-k3s,corp,p30}"
RUNNER_DESC="${GITLAB_RUNNER_DESCRIPTION:-p30-k3s-shell}"
RUNNER_USER="${GITLAB_RUNNER_USER:-bbv}"
NEXUS_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
RUNNER_IMAGE="${GITLAB_RUNNER_IMAGE:-${NEXUS_REGISTRY}/gitlab/gitlab-runner:latest}"

log() { printf '[gitlab-runner-p30] %s\n' "$*"; }

remote() {
  ssh "${SSH_HOST}" "$@"
}

remote_sudo() {
  remote "echo '${CXADO_OFFLINE_SUDO_PW}' | /usr/bin/sudo.ws -S $*"
}

install_binary() {
  log "install gitlab-runner binary from ${RUNNER_IMAGE}"
  remote "
    set -e
    if command -v gitlab-runner >/dev/null && gitlab-runner --version >/dev/null 2>&1; then
      gitlab-runner --version | head -1
      exit 0
    fi
    docker pull '${RUNNER_IMAGE}'
    docker rm -f gr-extract 2>/dev/null || true
    docker create --name gr-extract '${RUNNER_IMAGE}'
    docker cp gr-extract:/usr/bin/gitlab-runner /tmp/gitlab-runner
    docker rm gr-extract
    chmod +x /tmp/gitlab-runner
    /tmp/gitlab-runner --version | head -1
  "
  remote_sudo "install -m 755 /tmp/gitlab-runner /usr/local/bin/gitlab-runner"
  remote_sudo "gitlab-runner install --user=${RUNNER_USER} --working-directory=/home/${RUNNER_USER}"
  remote_sudo "systemctl enable gitlab-runner"
  remote_sudo "systemctl restart gitlab-runner"
  log "gitlab-runner service active on ${SSH_HOST}"
}

create_runner_token() {
  local pat="${GITLAB_PAT_RUNNER:-${GITLAB_TOKEN:-}}"
  if [[ -z "${pat}" ]]; then
    echo "missing GITLAB_PAT_RUNNER (needs api+create_runner) or GITLAB_TOKEN" >&2
    exit 2
  fi
  log "POST /api/v4/user/runners (project ${PROJECT_ID})"
  remote "curl -sk --request POST --url '${GITLAB_URL}/api/v4/user/runners' \
    --header 'PRIVATE-TOKEN: ${pat}' \
    --form 'runner_type=project_type' \
    --form 'project_id=${PROJECT_ID}' \
    --form 'description=${RUNNER_DESC}' \
    --form 'tag_list=${RUNNER_TAGS}' \
    --form 'run_untagged=false'"
}

register_runner() {
  local token="${GITLAB_RUNNER_TOKEN:-}"
  if [[ -z "${token}" ]]; then
    echo "missing GITLAB_RUNNER_TOKEN (glrt-...) in ${SECRETS}" >&2
    echo "Instance may block user runner creation — ask GitLab admin for a project runner token." >&2
    exit 2
  fi
  log "register runner on ${SSH_HOST} (tags: ${RUNNER_TAGS})"
  remote_sudo "gitlab-runner unregister --name '${RUNNER_DESC}' 2>/dev/null || true"
  remote_sudo "gitlab-runner register --non-interactive \
    --url '${GITLAB_URL}' \
    --token '${token}' \
    --executor shell \
    --description '${RUNNER_DESC}' \
    --tag-list '${RUNNER_TAGS}' \
    --run-untagged=false \
    --locked=false"
  remote_sudo "systemctl restart gitlab-runner"
  status_runner
}

status_runner() {
  remote_sudo "gitlab-runner list || true"
  remote_sudo "systemctl is-active gitlab-runner"
  remote "command -v kubectl >/dev/null && kubectl get nodes -o wide 2>/dev/null | head -5 || true"
}

cmd="${1:-install}"
case "${cmd}" in
  install) install_binary ;;
  register) install_binary; register_runner ;;
  create-token) create_runner_token ;;
  status) status_runner ;;
  *)
    echo "usage: $0 {install|register|create-token|status}" >&2
    exit 2
    ;;
esac
