# Bootstrap smoke test

Run on a clean machine (or temp directory) to verify cxado bootstrap.

## Checklist

- [ ] `git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git cxado-smoke`
- [ ] `cd cxado-smoke && make bootstrap`
- [ ] `test -d projects/veil/.git` — veil submodule initialized
- [ ] `test -d projects/egregore/.git` — egregore submodule initialized
- [ ] `test -d projects/fabrica/.git` — fabrica submodule initialized
- [ ] `test -d shared/skills/devsecops` — skills hub present
- [ ] `test -d refs/Jet-Container-Security-Framework-main` — references hub present (**optional**, gitignored; see `refs/README.md`)
- [ ] `test -f shared/contracts/engage-events-audit.json` — wire contracts present
- [ ] `test ! -e projects/veil/refs` — no legacy refs symlink (SSOT: `refs/` at meta root)
- [ ] `test -d shared/agent-rules/core` — agent rules hub present
- [ ] `test -L projects/veil/.cursor/rules/core-karpathy-guidelines.mdc` — core rules symlinked (veil)
- [ ] `test -L projects/fabrica/.agents/rules/core-karpathy-guidelines.mdc` — core rules symlinked (fabrica)
- [ ] `test -d projects/veneno/.git` — veneno submodule initialized
- [ ] `test -L projects/veneno/.agents/rules/core-karpathy-guidelines.mdc` — core rules symlinked (veneno)
- [ ] `test -L projects/fabrica/.agents/skills/devsecops-template` — skills-link (fabrica)
- [ ] `test -L ~/.cursor/skills/ai-agent-security` — agent skills installed (optional)
- [ ] `make test-contracts` — engage.events wire contract smoke

## Expected layout

```
cxado/
├── projects/veil/
├── projects/veneno/
├── projects/egregore/
├── projects/fabrica/
├── refs/
├── shared/skills/
├── shared/agent-rules/
├── shared/contracts/
└── cxado.code-workspace
```

## Legacy `.external/` (removed)

The manual `.external/` workspace copies are **deprecated**. Use submodules under `projects/` instead.
