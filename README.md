# cxado

Meta-repo for the cxado ecosystem: Veil, Veneno, Egregore, Fabrica, and ASOC API.

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
| `projects/veneno` | [butbeautifulv/veneno](https://github.com/butbeautifulv/veneno) |
| `projects/egregore` | [butbeautifulv/egregore](https://github.com/butbeautifulv/egregore) |
| `projects/fabrica` | [butbeautifulv/fabrica](https://github.com/butbeautifulv/fabrica) |
| `projects/asoc-api` | [butbeautifulv/asoc-api](https://github.com/butbeautifulv/asoc-api) |

## Shared hubs

| Submodule | Repository | Purpose |
|-----------|------------|---------|
| `shared/skills` | [cxado-skills](https://github.com/butbeautifulv/cxado-skills) | 13 Cursor dev skills |
| `shared/references` | [cxado-references](https://github.com/butbeautifulv/cxado-references) | JCSF, DAF, hexstrike, OWASP PDFs |
| `shared/gui` | [cxado-gui](https://github.com/butbeautifulv/cxado-gui) | Reusable compliance UI kit (`@cxado/gui`) |

Open multi-root workspace: `cxado.code-workspace`

## Migration from manual `.external/`

| Was | Now |
|-----|-----|
| Copy repos into `.external/` by hand | `git clone cxado && make bootstrap` |
| Skills in each project | `make skills-install` (or full `make bootstrap`) |
| JCSF/DAF in 3 places | `shared/references/` + `make refs-link` |
| Desktop duplicate clones | Single `cxado` workspace |

Legacy `.external/` at workspace root is **removed** — use `projects/` submodules.
