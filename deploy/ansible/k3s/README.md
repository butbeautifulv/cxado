# k3s offline bootstrap (Ansible)

Air-gap Ansible playbooks to bootstrap k3s **control plane** and **worker** nodes for the cxado offline stack. Matches the baseline on `bbv-P30-K44` (`10.8.185.15`): k3s `v1.35.0+k3s1`, Helm `v4.1.0`, SSH ports `22` + `22012`, hostPath dirs, user kubeconfig.

Application deployment (egregore, veil, obs) stays in existing shell scripts under [`scripts/k8s/`](../../../scripts/k8s/).

## Prerequisites

- Ansible 2.14+ on the laptop (controller)
- SSH access to target nodes (passwordless sudo or `--ask-become-pass`)
- Internet on the **controller only** (to fetch airgap artifacts once)

## Quick start

```bash
# 1. Fetch offline artifacts (controller, with internet)
./scripts/k8s/k3s-airgap-fetch.sh

# 2. Configure inventory
cd deploy/ansible/k3s
cp inventories/offline/hosts.yml.example inventories/offline/hosts.yml
# edit hosts.yml — ansible_host, k3s_node_ip, TLS SANs

# 3. Bootstrap control plane (+ optional workers)
ansible-playbook -i inventories/offline playbooks/site.yml --ask-become-pass
```

### Control plane only

```bash
ansible-playbook -i inventories/offline playbooks/server.yml --ask-become-pass
```

### Add workers later

Ensure the server is running, then:

```bash
ansible-playbook -i inventories/offline playbooks/agent.yml --ask-become-pass
```

## Inventory groups

| Group | Role |
|-------|------|
| `k3s_server` | First host initializes the cluster; installs k3s server, Helm, kubeconfig |
| `k3s_agent` | Workers join via node token from the first server |

Per-host variables:

| Variable | Description |
|----------|-------------|
| `ansible_host` | SSH target (WiFi IP or NAT hop) |
| `ansible_port` | SSH port (`22` WiFi, `22012` corp NAT on node) |
| `k3s_node_ip` | Stable node IP for k3s `node-ip` / TLS (corp ethernet recommended) |
| `k3s_tls_sans` | Extra TLS SANs (hostname, WiFi IP, localhost) |

Defaults align with [`scripts/k8s/cxado-offline-env.sh`](../../../scripts/k8s/cxado-offline-env.sh):

| Access path | SSH | Node IP |
|-------------|-----|---------|
| WiFi direct | `bbv-p30-wifi:22` → `192.168.0.133` | `192.168.0.133` or corp `10.8.185.15` |
| Corp NAT | `bbv-p30-k44:22012` via `10.8.184.22` | `10.8.185.15` |

Corp NAT (`10.8.184.22:22012 → 10.8.185.15:22012`) is configured **outside** this repo (router/firewall DNAT). Ansible only opens port `22012` in `sshd`.

## What gets installed

- **OS prep**: Docker, sysctl, kernel modules (`br_netfilter`, `overlay`)
- **SSH**: drop-in `/etc/ssh/sshd_config.d/99-cxado-wifi.conf` (ports 22 + 22012)
- **k3s** (offline): binary + airgap images, systemd network-online drop-in
- **Helm** (offline): `/usr/local/bin/helm`
- **kubeconfig**: `/home/bbv/.kube/config` (for `k3s kubectl` / deploy scripts)
- **hostPath dirs**:
  - `/var/lib/veil/playbooks/docs/skills-index`
  - `/home/bbv/cxado/arch-docs`
  - `/var/lib/cxado/prom-multiproc`

Traefik is **not** disabled (matches current single-node baseline).

## After bootstrap

Deploy the cxado stack with existing scripts:

```bash
CXADO_OFFLINE_SSH_HOST=bbv-p30-wifi ./scripts/k8s/k3s-deploy-cxado-offline.sh --with-veil
```

See also:

- [docs/deploy/k3s-offline-baseline.md](../../../docs/deploy/k3s-offline-baseline.md)
- [deploy/ports.md](../../../deploy/ports.md)

## Airgap artifacts

Fetched by [`scripts/k8s/k3s-airgap-fetch.sh`](../../../scripts/k8s/k3s-airgap-fetch.sh) into `files/airgap/` (gitignored):

| File | Purpose |
|------|---------|
| `k3s`, `k3s-arm64` | k3s binaries |
| `install.sh` | k3s installer (with `INSTALL_K3S_SKIP_DOWNLOAD=true`) |
| `k3s-airgap-images-amd64.tar` | Embedded k3s images |
| `helm-v4.1.0-linux-amd64.tar.gz` | Helm binary |

Override versions:

```bash
K3S_VERSION=v1.35.0+k3s1 HELM_VERSION=v4.1.0 ARCH=amd64 ./scripts/k8s/k3s-airgap-fetch.sh
```

## Verification checklist

After `site.yml` on a fresh node:

1. `k3s kubectl get nodes` — control-plane Ready
2. `ssh -p 22` and `ssh -p 22012` reach the node
3. `helm version` on server
4. `KUBECONFIG=~/.kube/config k3s kubectl get pods -A` as user `bbv`
5. hostPath directories exist with correct ownership
6. With workers: 2+ nodes Ready; worker labeled `node-role.kubernetes.io/worker=true`
7. `./scripts/k8s/k3s-offline-bundle-min.sh` image import works without manual fixes

## Secrets

- Use `--ask-become-pass` or `ansible_become_password` (same as `CXADO_OFFLINE_SUDO_PW` in deploy scripts)
- `k3s_node_token` is read from the server at runtime — do not commit
- `inventories/offline/hosts.yml` is gitignored; only `hosts.yml.example` is tracked

## Out of scope (v1)

- HA control plane (3× server)
- Automated cxado/veil/obs stack deploy via Ansible
- UFW / NodePort firewall rules (open `30000-32767` manually if needed)
- Standalone `kubectl` binary
