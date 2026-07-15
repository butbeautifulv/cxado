# cxado references (local only — gitignored)

JCSF, DAF, OWASP extracts. **Not tracked in git** (~1 GB). Projects access via `make refs-link` → `refs/`.

## Populate locally

If you had the old submodule checkout, it should still be on disk at `shared/references/`.

Otherwise restore from backup or clone the archived private repo (if you still have access):

```bash
# one-time: replace this directory contents
git clone https://github.com/butbeautifulv/cxado-references.git /tmp/cxado-references
rsync -a /tmp/cxado-references/ ./shared/references/
rm -rf /tmp/cxado-references
```

Then from cxado root: `make refs-link`

**Not included in references tree:** `Anthropic-Cybersecurity-Skills-main/` (Veil-local for `make corpus-import`).
