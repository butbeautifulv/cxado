# JCSF implementation checklist

## E1 Admission (`orchr`, `man`)

- [ ] Kyverno or OPA policies in `templates/k8s/admission/`
- [ ] PSA / restricted defaults
- [ ] Conftest in CI: `templates/gitlab/jobs/conftest-admission.yml`
- [ ] Block :latest, require labels, deny privileged

## E2 Network (`gen`)

- [ ] Default deny NetworkPolicy
- [ ] Namespace-scoped allow lists
- [ ] Ingress/egress for DNS, API

## E3 Runtime (`cont`)

- [ ] Falco helm values stub
- [ ] Seccomp/AppArmor profiles doc
- [ ] Exec/shell anomaly rules

## C3 Registry (`img`)

- [ ] `templates/k8s/cluster/image-pull-policy.md`
- [ ] Internal registry only on workers
- [ ] Periodic registry scan (cron, outside pipeline)

## B5 Docker (`Dock`)

- [ ] Hadolint + Checkov dockerfile
- [ ] Non-root USER, no secrets in layers
- [ ] CIS Docker sheet cross-check

## Preprod vs prod

| Env | JCSF focus |
|-----|------------|
| Preprod | man scan, DAST, vuln scan |
| Prod | orchr, gen, cont, img monitor |

Contact (JCSF README): dso@jet.su
