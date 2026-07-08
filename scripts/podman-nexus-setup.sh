#!/usr/bin/env bash
# Configure podman to pull docker.io via Nexus and log in.
#
# Usage:
#   ./scripts/podman-nexus-setup.sh              # local host
#   ./scripts/podman-nexus-setup.sh vm-01        # SSH host alias (~/.ssh/config)
#   ./scripts/podman-nexus-setup.sh bbv-p30-wifi   # P30 k3s node (podman + docker)
#
# Secrets (gitignored): deploy/.secrets/cxado-k3s.env
#   NEXUS_DOCKER_REGISTRY=nexus.svo.aero:8345
#   NEXUS_USER=admin-SEC
#   NEXUS_PASSWORD=...
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS="${ROOT}/deploy/.secrets/cxado-k3s.env"
REGISTRY_CONF="${ROOT}/deploy/containers/registries.conf.d/nexus.conf"
REGISTRY_GROUP_CONF="${ROOT}/deploy/containers/registries.conf.d/nexus-group.conf"
PODMAN_CONF="${ROOT}/deploy/containers/podman.conf"
NEXUS_DOCKER_GROUP_REGISTRY="${NEXUS_DOCKER_GROUP_REGISTRY:-nexus.svo.aero:8374}"
REMOTE_HOST="${1:-}"
REMOTE_USER="${2:-}"

log() { printf '[podman-nexus-setup] %s\n' "$*"; }

if [[ -f "${SECRETS}" ]]; then
  # shellcheck disable=SC1090
  source "${SECRETS}"
fi

remote_sudo_pw() {
  case "${REMOTE_HOST}" in
    vm-01|defectdojo-vm|svo-aosint-ps01) echo "${VM_01_PWD:-}" ;;
    vm-02|svo-pntmon-ps01) echo "${VM_02_PWD:-}" ;;
    bbv-p30-wifi|p30-wifi|bbv-p30|bbv-p30-k44|p30)
      echo "${CXADO_OFFLINE_SUDO_PW:-${REMOTE_SUDO_PW:-}}"
      ;;
    *) echo "${REMOTE_SUDO_PW:-}" ;;
  esac
}

NEXUS_DOCKER_REGISTRY="${NEXUS_DOCKER_REGISTRY:-nexus.svo.aero:8345}"
NEXUS_USER="${NEXUS_USER:-${NEXUS_REPO_USER:-admin-SEC}}"
NEXUS_PASSWORD="${NEXUS_PASSWORD:-${NEXUS_REPO_PASSWORD:-}}"

if [[ -z "${NEXUS_PASSWORD}" ]]; then
  echo "missing NEXUS_PASSWORD (set in ${SECRETS})" >&2
  exit 2
fi

if [[ ! -f "${REGISTRY_CONF}" ]]; then
  echo "missing ${REGISTRY_CONF}" >&2
  exit 2
fi

if [[ ! -f "${PODMAN_CONF}" ]]; then
  echo "missing ${PODMAN_CONF}" >&2
  exit 2
fi

run_remote() {
  local ssh_target
  if [[ -n "${REMOTE_USER}" ]]; then
    ssh_target="${REMOTE_USER}@${REMOTE_HOST}"
  else
    ssh_target="${REMOTE_HOST}"
  fi
  ssh "${ssh_target}" "NEXUS_DOCKER_REGISTRY='${NEXUS_DOCKER_REGISTRY}' NEXUS_USER='${NEXUS_USER}' NEXUS_PASSWORD='${NEXUS_PASSWORD}' REMOTE_SUDO_PW='$(remote_sudo_pw)' bash -s" <<EOS
set -euo pipefail
REGISTRY="${NEXUS_DOCKER_REGISTRY}"
TARGET="/etc/containers/registries.conf.d/nexus.conf"
PODMAN_CONF_SRC="\$(mktemp)"
TMP="\$(mktemp)"
sudo_install() {
  if [[ -n "\${REMOTE_SUDO_PW:-}" ]]; then
    echo "\${REMOTE_SUDO_PW}" | sudo -S -p "" "\$@"
  else
    sudo "\$@"
  fi
}
printf '%s\n' '{}' > "\${PODMAN_CONF_SRC}"
install_podman_conf() {
  if [[ -f /etc/podman.conf ]] && grep -q '^{}\$' /etc/podman.conf 2>/dev/null; then
    return 0
  fi
  sudo_install install -m 0644 "\${PODMAN_CONF_SRC}" /etc/podman.conf
  echo "[remote] installed /etc/podman.conf"
}
install_podman_conf
rm -f "\${PODMAN_CONF_SRC}"
cat >"\${TMP}" <<EOF
unqualified-search-registries = ["docker.io"]

[[registry]]
prefix = "docker.io"
location = "\${REGISTRY}"
insecure = true

[[registry]]
location = "\${REGISTRY}"
insecure = true

[[registry]]
location = "${NEXUS_DOCKER_GROUP_REGISTRY}"
insecure = true
EOF
if [[ -w /etc/containers/registries.conf.d ]]; then
  install -m 0644 "\${TMP}" "\${TARGET}"
else
  sudo_install install -m 0644 "\${TMP}" "\${TARGET}"
fi
rm -f "\${TMP}"
echo "[remote] installed \${TARGET}"
cat "\${TARGET}"
echo "[remote] podman login \${REGISTRY}"
echo "\${NEXUS_PASSWORD}" | podman login --tls-verify=false "\${REGISTRY}" -u "\${NEXUS_USER}" --password-stdin
podman login --get-login "\${REGISTRY}"
echo "[remote] smoke pull (podman)"
podman pull docker.io/library/alpine:3.20 || echo "[remote] WARN: podman smoke pull failed (rootless UID issue is OK if docker works)"
if command -v docker >/dev/null 2>&1; then
  echo "[remote] docker daemon.json"
  DOCKER_TMP="\$(mktemp)"
  cat >"\${DOCKER_TMP}" <<DOCKERJSON
{
  "insecure-registries": ["\${REGISTRY}", "${NEXUS_DOCKER_GROUP_REGISTRY}"],
  "registry-mirrors": ["https://\${REGISTRY}"]
}
DOCKERJSON
  sudo_install cp "\${DOCKER_TMP}" /etc/docker/daemon.json
  rm -f "\${DOCKER_TMP}"
  sudo_install mkdir -p /etc/docker/certs.d/nexus.svo.aero:8345
  openssl s_client -connect nexus.svo.aero:8345 -servername nexus.svo.aero </dev/null 2>/dev/null | openssl x509 -outform PEM > /tmp/nexus-ca.crt || true
  if [[ -s /tmp/nexus-ca.crt ]]; then
    sudo_install cp /tmp/nexus-ca.crt /etc/docker/certs.d/nexus.svo.aero:8345/ca.crt
  fi
  sudo_install systemctl restart docker
  sleep 2
  if getent group docker >/dev/null 2>&1; then
    sudo_install usermod -aG docker "\${USER}" 2>/dev/null || true
  fi
  echo "[remote] docker login \${REGISTRY}"
  printf '%s\n' "\${REMOTE_SUDO_PW}" | sudo -S -p "" env NEXUS_PASSWORD="\${NEXUS_PASSWORD}" REGISTRY="\${REGISTRY}" NEXUS_USER="\${NEXUS_USER}" \
    bash -c 'echo "\$NEXUS_PASSWORD" | docker login "\$REGISTRY" -u "\$NEXUS_USER" --password-stdin'
  echo "[remote] smoke pull (docker via nexus)"
  printf '%s\n' "\${REMOTE_SUDO_PW}" | sudo -S -p "" docker pull "\${REGISTRY}/library/alpine:3.20" || echo "[remote] WARN: docker pull failed"
fi
EOS
}

run_local() {
  local target="/etc/containers/registries.conf.d/nexus.conf"
  if [[ ! -f /etc/podman.conf ]]; then
    log "install /etc/podman.conf"
    if [[ -w /etc ]]; then
      install -m 0644 "${PODMAN_CONF}" /etc/podman.conf
    else
      sudo install -m 0644 "${PODMAN_CONF}" /etc/podman.conf
    fi
  fi
  log "install ${target}"
  if [[ -w /etc/containers/registries.conf.d ]]; then
    install -m 0644 "${REGISTRY_CONF}" "${target}"
    install -m 0644 "${REGISTRY_GROUP_CONF}" /etc/containers/registries.conf.d/nexus-group.conf
  else
    sudo install -m 0644 "${REGISTRY_CONF}" "${target}"
    sudo install -m 0644 "${REGISTRY_GROUP_CONF}" /etc/containers/registries.conf.d/nexus-group.conf
  fi
  log "podman login ${NEXUS_DOCKER_REGISTRY}"
  echo "${NEXUS_PASSWORD}" | podman login --tls-verify=false "${NEXUS_DOCKER_REGISTRY}" -u "${NEXUS_USER}" --password-stdin
  podman login --get-login "${NEXUS_DOCKER_REGISTRY}"
  log "smoke pull docker.io/library/alpine:3.20"
  podman pull docker.io/library/alpine:3.20
}

if [[ -n "${REMOTE_HOST}" ]]; then
  log "remote ${REMOTE_HOST}"
  run_remote
else
  log "local"
  run_local
fi

log "done"
