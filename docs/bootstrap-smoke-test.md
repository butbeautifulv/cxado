# Bootstrap smoke test

Run on a clean machine (or temp directory) to verify cxado bootstrap.

## Checklist

- [ ] `git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git cxado-smoke`
- [ ] `cd cxado-smoke && make bootstrap`
- [ ] `test -d projects/veil/.git` — veil submodule initialized
- [ ] `test -d projects/egregore/.git` — egregore submodule initialized
- [ ] `test -d projects/fabrica/.git` — fabrica submodule initialized
- [ ] `test -d projects/asoc-api/.git` — asoc-api submodule initialized
- [ ] `test -d shared/skills/devsecops` — skills hub present
- [ ] `test -d shared/references/Jet-Container-Security-Framework-main` — references hub present
- [ ] `test -d shared/references/owasp` — OWASP cheat sheets in references hub
- [ ] `test -f shared/contracts/engage-events-audit.json` — wire contracts present
- [ ] `test -L projects/veil/refs` — refs symlink created
- [ ] `test -L projects/fabrica/refs` — refs symlink created
- [ ] `test -L projects/egregore/refs` — refs symlink created (egregore)
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
├── projects/asoc-api/
├── shared/skills/
├── shared/references/
├── shared/agent-rules/
├── shared/contracts/
└── cxado.code-workspace
```

## Legacy `.external/` (removed)

The manual `.external/` workspace copies are **deprecated**. Use submodules under `projects/` instead.
