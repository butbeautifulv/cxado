# cxado references (local only — gitignored)

JCSF, DAF, OWASP extracts. **Not tracked in git** (~1 GB). Canonical path: **`refs/`** at cxado meta-repo root (no per-project symlinks).

## Populate locally

If you had the old `shared/references/` checkout, it should now live here at `refs/`.

Otherwise restore from backup or clone the archived private repo (if you still have access):

```bash
# one-time: populate refs/ at cxado root
git clone https://github.com/butbeautifulv/cxado-references.git /tmp/cxado-references
rsync -a /tmp/cxado-references/ ./refs/
rm -rf /tmp/cxado-references
```

From projects in the monorepo, reference as `../../refs/` (e.g. `projects/veil/../../refs/owasp/`).

**Not included in references tree:** `Anthropic-Cybersecurity-Skills-main/` (Veil-local for `make corpus-import`).
