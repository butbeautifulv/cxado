# cxado-kind Terraform

Deploys full cxado stack on an existing **kind** cluster via Helm.

## Usage

```bash
make cxado-kind-up
make cxado-k8s-build-images
make cxado-tf-init
make cxado-tf-apply
```

Requires: terraform >= 1.5, helm, kubectl context `kind-cxado`.

See [docs/deploy/cxado-kubernetes-kind.md](../../../docs/deploy/cxado-kubernetes-kind.md).
