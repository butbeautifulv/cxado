# Bootstrap smoke test

Run on a clean machine (or temp directory) to verify cxado bootstrap.

## Checklist

- [ ] `git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git cxado-smoke`
- [ ] `cd cxado-smoke && make bootstrap`
- [ ] `test -d projects/veil/.git` — veil submodule initialized
- [ ] `test -d projects/cys-agi/.git` — cys-agi submodule initialized
- [ ] `test -d projects/ci-cd-template/.git` — ci-cd-template submodule initialized
- [ ] `test -d projects/asoc-api/.git` — asoc-api submodule initialized
- [ ] `test -d shared/skills/devsecops` — skills hub present
- [ ] `test -d shared/references/Jet-Container-Security-Framework-main` — references hub present
- [ ] `test -L projects/veil/refs` — refs symlink created
- [ ] `test -L projects/ci-cd-template/refs` — refs symlink created
- [ ] `test -L ~/.cursor/skills/devsecops-template` — skills installed (optional)

## Expected layout

```
cxado/
├── projects/veil/
├── projects/cys-agi/
├── projects/ci-cd-template/
├── projects/asoc-api/
├── shared/skills/
├── shared/references/
└── cxado.code-workspace
```

## Legacy `.external/` (removed)

The manual `.external/` workspace copies are **deprecated**. Use submodules under `projects/` instead.
