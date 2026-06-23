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

## Shared hubs

| Submodule | Repository | Purpose |
|-----------|------------|---------|
| `shared/skills` | [cxado-skills](https://github.com/butbeautifulv/cxado-skills) | 13 Cursor dev skills |
| `shared/references` | [cxado-references](https://github.com/butbeautifulv/cxado-references) | JCSF, DAF, hexstrike, OWASP PDFs |

Open multi-root workspace: `cxado.code-workspace`

## Migration from manual `.external/`

| Was | Now |
|-----|-----|
| Copy repos into `.external/` by hand | `git clone cxado && make bootstrap` |
| Skills in each project | `make skills-install` (or full `make bootstrap`) |
| JCSF/DAF in 3 places | `shared/references/` + `make refs-link` |
| Desktop duplicate clones | Single `cxado` workspace |

Legacy `.external/` at workspace root is **removed** — use `projects/` submodules.
