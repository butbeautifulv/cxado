---
name: devsecops-jcsf
description: >-
  Jet Container Security Framework: K8s domains gen/nodes/orchr/man/img/cont/Dock,
  CIS benchmarks, runtime and admission controls. Use for K8s hardening, E-phases,
  or mapping JCSF practices to templates/k8s/.
---

# JCSF (Jet Container Security Framework)

Source: `docs/references/extracts/jcsf/`

Repo: `docs/06-kubernetes-runtime.md`, `templates/k8s/`.

## Domains

| Code | Domain | Template path |
|------|--------|---------------|
| gen | Segmentation, L3/L4 FW | `templates/k8s/network/` |
| nodes | OS hardening | golden image / IaC |
| orchr | API server, admission | `templates/k8s/admission/` |
| man | Manifests, Helm | B4 iac + admission |
| img | Images, registry CVE | C2, C3, C4 |
| cont | Runtime (Falco, seccomp) | `templates/k8s/runtime/` |
| Dock | Dockerfile, build host | B5 dockerfile-lint |

Levels: L0 Uninitiated → L4 Experts. Template targets L2–L3 for E-phases.

## CIS / regulatory sheets

| Sheet | Use |
|-------|-----|
| CIS Docker | B5, build workers |
| CIS Kubernetes | E1, E2 |
| CIS Linux | node hardening |
| Приказ 118 | ФСТЭК mapping |

## DAF overlap

| DAF | JCSF |
|-----|------|
| T-PROD-RUN | orchr, cont |
| T-CODE-IMG | img |
| T-CODE-DOCKERFS | Dock |
| T-PREPROD-MANSEC | man |
| T-PROD-NETWORK | gen |

## L1–L2 anchor practices

- Orch-1-1 — kube-apiserver authn/authz
- Orch-2-13 — admission controller / policy engine
- Img-1-1 — image scan policy
- Nodes-2-3 — OS vulnerability scan
- Cont-1-* — runtime detection (Falco)
- Dock-1-* — secure image build

## Out of CI

WAF, RASP → `docs/phases/F2-rasp-waf.md` only.

Full practice list: [reference.md](reference.md)
