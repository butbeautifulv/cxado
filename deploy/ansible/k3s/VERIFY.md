# Verification log (2026-07-03)

Automated checks run against the live node `bbv-P30-K44` via corp NAT hop.

## Ansible syntax

```bash
python3 -m venv /tmp/ansible-venv
/tmp/ansible-venv/bin/pip install ansible-core
/tmp/ansible-venv/bin/ansible-playbook --syntax-check \
  -i /tmp/k3s-test-inventory.yml \
  deploy/ansible/k3s/playbooks/site.yml
# -> playbook: playbooks/site.yml (OK)
```

## SSH connectivity (Ansible ping)

```bash
ANSIBLE_BECOME=false ansible -i /tmp/k3s-verify-inventory.yml k3s_server -m ping
# -> p30-k44 | SUCCESS => ping: pong
```

Inventory used for live check:

- `ansible_host: 10.8.184.22`
- `ansible_port: 22012`
- `k3s_node_ip: 10.8.185.15`

## Baseline artifact smoke (SSH)

Confirmed on node:

- `/etc/ssh/sshd_config.d/99-cxado-wifi.conf`
- hostPath dirs: veil skills-index, arch-docs, prom-multiproc
- `k3s version v1.35.0+k3s1`
- `helm version v4.1.0`
- `/home/bbv/.kube/config`

## Full bootstrap dry-run

Not executed on the production node (would require `--ask-become-pass` and could disturb running k3s). Use a fresh VM for end-to-end `site.yml` validation.

Checklist for fresh nodes: see [README.md](README.md#verification-checklist).
