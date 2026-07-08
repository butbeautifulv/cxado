#!/usr/bin/env bash
# Run k3s Ansible playbooks with secrets from deploy/.secrets/cxado-k3s.env only.
#
# Usage:
#   ./scripts/k8s/k3s-ansible-playbook.sh playbooks/site.yml
#   ./scripts/k8s/k3s-ansible-playbook.sh playbooks/agent.yml
#
# Requires: ansible in .venv-ansible (created on first run) or ansible-playbook in PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
K3S_DIR="${ROOT}/deploy/ansible/k3s"
VENV="${ROOT}/.venv-ansible"

if [[ ! -f "${SECRETS}" ]]; then
  echo "missing ${SECRETS} — copy from deploy/.secrets/cxado-k3s.env.example" >&2
  exit 2
fi

# shellcheck source=deploy/registry.defaults.env
[[ -f "${ROOT}/deploy/registry.defaults.env" ]] && source "${ROOT}/deploy/registry.defaults.env"
# shellcheck source=/dev/null
source "${SECRETS}"

for var in CXADO_OFFLINE_SUDO_PW VM_01_PWD VM_02_PWD NEXUS_USER NEXUS_PASSWORD; do
  if [[ -z "${!var:-}" ]]; then
    echo "missing ${var} in ${SECRETS}" >&2
    exit 2
  fi
done

export CXADO_OFFLINE_SUDO_PW VM_01_PWD VM_02_PWD
export NEXUS_USER NEXUS_PASSWORD
export NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
export NEXUS_DOCKER_GROUP_REGISTRY="${NEXUS_DOCKER_GROUP_REGISTRY:-nexus.svo.aero:8374}"
export NEXUS_CXADO_DOCKER_REPO="${NEXUS_CXADO_DOCKER_REPO:-cxado-docker}"
export NEXUS_API_URL="${NEXUS_API_URL:-https://nexus.svo.aero:8443}"
export NEXUS_K3S_PROXY_REPO="${NEXUS_K3S_PROXY_REPO:-k3s-releases-proxy}"
export NEXUS_K3S_GET_PROXY_REPO="${NEXUS_K3S_GET_PROXY_REPO:-k3s-get-proxy}"
export NEXUS_HELM_PROXY_REPO="${NEXUS_HELM_PROXY_REPO:-helm-get-proxy}"

if [[ -x "${VENV}/bin/ansible-playbook" ]]; then
  ANSIBLE_PLAYBOOK="${VENV}/bin/ansible-playbook"
elif command -v ansible-playbook >/dev/null 2>&1; then
  ANSIBLE_PLAYBOOK="$(command -v ansible-playbook)"
else
  python3 -m venv "${VENV}"
  "${VENV}/bin/pip" install -q ansible-core
  ANSIBLE_PLAYBOOK="${VENV}/bin/ansible-playbook"
fi

PLAYBOOK="${1:-playbooks/site.yml}"
shift || true

cd "${K3S_DIR}"
exec env ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_STDOUT_CALLBACK=default \
  "${ANSIBLE_PLAYBOOK}" -i inventories/offline/hosts.yml "${PLAYBOOK}" "$@"
