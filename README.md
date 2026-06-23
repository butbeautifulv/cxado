# cxado

Meta-repo for the cxado ecosystem: Veil, cys-agi, CI/CD template, and ASOC API.

## Clone workflow

```bash
git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git
cd cxado
make bootstrap
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
# or
make bootstrap
```

## Projects

| Submodule | Repository |
|-----------|------------|
| `projects/veil` | [butbeautifulv/veil](https://github.com/butbeautifulv/veil) |
| `projects/cys-agi` | [butbeautifulv/cys_agi](https://github.com/butbeautifulv/cys_agi) |
| `projects/ci-cd-template` | [butbeautifulv/ci-cd_template](https://github.com/butbeautifulv/ci-cd_template) |
| `projects/asoc-api` | [butbeautifulv/asoc-api](https://github.com/butbeautifulv/asoc-api) |
