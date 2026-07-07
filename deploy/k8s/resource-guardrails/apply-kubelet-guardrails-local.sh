#!/usr/bin/env bash
# Run ON the k3s node (P30) with sudo to enable kubelet eviction guardrails.
# Laptop: rsync deploy/k8s/resource-guardrails/ to the node, then:
#   sudo ./apply-kubelet-guardrails-local.sh
set -euo pipefail

CFG="${K3S_CONFIG:-/etc/rancher/k3s/config.yaml}"
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
lines = cfg_path.read_text().splitlines() if cfg_path.exists() else []

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

out_path.write_text("\n".join(out).rstrip() + "\n")
PY

if ! diff -q "$CFG" "$TMP" >/dev/null 2>&1; then
  cp "$TMP" "$CFG"
  echo "updated $CFG; restarting k3s"
  systemctl restart k3s
  systemctl is-active k3s
else
  echo "kubelet guardrails already present in $CFG"
fi
rm -f "$TMP"
