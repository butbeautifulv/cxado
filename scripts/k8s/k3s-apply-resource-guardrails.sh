#!/usr/bin/env bash
# Apply host protection for single-node k3s offline (P30):
#   1. kubelet reservations + eviction (~90% RAM ceiling)
#   2. ResourceQuota / LimitRange on cxado-app
#   3. egregore helm: worker limits + fewer replicas + capped HPA (with --helm)
#
# Usage:
#   ./scripts/k8s/k3s-apply-resource-guardrails.sh
#   CXADO_OFFLINE_TAG=offline-20260707-grounding ./scripts/k8s/k3s-apply-resource-guardrails.sh --helm
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/k8s/cxado-offline-env.sh
source "${ROOT}/scripts/k8s/cxado-offline-env.sh"

SSH_HOST="${CXADO_OFFLINE_SSH_HOST}"
SSH_PORT="${CXADO_OFFLINE_SSH_PORT}"
K3S_CONFIG="${CXADO_K3S_CONFIG:-/etc/rancher/k3s/config.yaml}"
NS_APP="${CXADO_APP_NS:-cxado-app}"
KCTL="KUBECONFIG=/home/bbv/.kube/config k3s kubectl"
RUN_HELM=false

log() { printf '[resource-guardrails] %s\n' "$*"; }

for arg in "$@"; do
  case "$arg" in
    --helm) RUN_HELM=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $arg (try --helm)" >&2; exit 2 ;;
  esac
done

log "ssh=${SSH_HOST}:${SSH_PORT}"

ssh -p "${SSH_PORT}" "${SSH_HOST}" bash -s -- "${K3S_CONFIG}" <<'REMOTE'
set -euo pipefail
CFG="$1"
TMP="$(mktemp)"
declare -a WANT=(
  'system-reserved=cpu=400m,memory=1536Mi,ephemeral-storage=2Gi'
  'kube-reserved=cpu=400m,memory=1024Mi,ephemeral-storage=1Gi'
  'eviction-hard=memory.available<1Gi,nodefs.available<10%,imagefs.available<10%'
  'eviction-soft=memory.available<1536Mi'
  'eviction-soft-grace-period=memory.available=2m'
  'eviction-max-pod-grace-period=60'
)

python3 - "$CFG" "$TMP" "${WANT[@]}" <<'PY'
import pathlib
import sys

cfg_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
wanted = sys.argv[3:]
lines: list[str] = []
if cfg_path.exists():
    lines = cfg_path.read_text().splitlines()

out: list[str] = []
i = 0
replaced = False
while i < len(lines):
    line = lines[i]
    if line.strip().startswith("kubelet-arg:"):
        out.append("kubelet-arg:")
        for arg in wanted:
            out.append(f'  - "{arg}"')
        replaced = True
        i += 1
        while i < len(lines) and lines[i].startswith("  -"):
            i += 1
        continue
    out.append(line)
    i += 1

if not replaced:
    if out and out[-1].strip():
        out.append("")
    out.append("kubelet-arg:")
    for arg in wanted:
        out.append(f'  - "{arg}"')

new_text = "\n".join(out).rstrip() + "\n"
out_path.write_text(new_text)
old_text = cfg_path.read_text() if cfg_path.exists() else ""
print("changed" if new_text != old_text else "unchanged")
PY

if [[ "$(cat "$TMP" | sha256sum | awk '{print $1}')" != "$(sudo sha256sum "$CFG" 2>/dev/null | awk '{print $1}' || echo none)" ]]; then
  if ! sudo -n true 2>/dev/null; then
    echo "WARN: kubelet guardrails need sudo on the node. Run on P30:" >&2
    echo "  sudo cp $TMP $CFG && sudo systemctl restart k3s" >&2
    echo "skipped-kubelet-restart" > /tmp/k3s-guardrails-status
  else
    sudo cp "$TMP" "$CFG"
    echo "k3s config updated; restarting k3s"
    sudo systemctl restart k3s
    for _ in $(seq 1 30); do
      if sudo systemctl is-active --quiet k3s; then
        break
      fi
      sleep 2
    done
    sudo systemctl is-active k3s
    echo "applied" > /tmp/k3s-guardrails-status
  fi
else
  echo "k3s config already has kubelet guardrails"
  echo "unchanged" > /tmp/k3s-guardrails-status
fi
rm -f "$TMP"
REMOTE

GUARD_STATUS="$(ssh -p "${SSH_PORT}" "${SSH_HOST}" "cat /tmp/k3s-guardrails-status 2>/dev/null || echo unknown")"
if [[ "$GUARD_STATUS" == "skipped-kubelet-restart" ]]; then
  log "kubelet eviction not applied (sudo required on node)"
fi

ssh -p "${SSH_PORT}" "${SSH_HOST}" "${KCTL} create ns ${NS_APP} 2>/dev/null || true"
rsync -a -e "ssh -p ${SSH_PORT}" \
  "${ROOT}/deploy/k8s/resource-guardrails/" \
  "${SSH_HOST}:/tmp/resource-guardrails/"
ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} apply -f /tmp/resource-guardrails/cxado-app-quota.yaml"

if [[ "$RUN_HELM" == true ]]; then
  log "helm upgrade via egregore-helm-upgrade.sh"
  "${ROOT}/scripts/k8s/egregore-helm-upgrade.sh"
fi

log "current node + cxado-app usage:"
ssh -p "${SSH_PORT}" "${SSH_HOST}" \
  "${KCTL} top nodes 2>/dev/null || true; ${KCTL} -n ${NS_APP} get deploy; ${KCTL} -n ${NS_APP} get hpa 2>/dev/null || true"

log "done"
