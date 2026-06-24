# Tabula — compliance domain (planned umbrella)

Tabula is the planned **compliance** domain for cxado. [fstec](https://github.com/butbeautifulv/fstec) is the first product module (FSTEC measures, orders, organizations).

## Status

| Item | State |
|------|-------|
| fstec product repo | Active on `master`; GUI migration **paused** on `fstec/gui-detach-wip` |
| Tabula umbrella repo | Not created — fstec remains standalone for now |
| `@cxado/gui` | Stable in [shared/gui](../../shared/gui); consumer wiring deferred |

## Target layout (phase 3)

```
tabula/                    # future umbrella (submodule or meta-package)
  fstec/                   # submodule → butbeautifulv/fstec
  docs/
  shared-contracts/        # optional compliance event schemas → shared/contracts/
```

## GUI migration resume path

When resuming `fstec/gui-detach-wip`:

1. Pin [shared/gui](../../shared/gui) @ `cxado-gui` main (not sibling `fstec/cxado-gui`).
2. Consumer dependency: `file:../../shared/gui` or `make gui-link` from cxado root.
3. Wire `globals.css` → `@import "@cxado/gui/tailwind.preset.css"`.
4. Complete dashboard hybrid tables; run `npm run build` on WIP branch.
5. Merge into fstec `master` only after Tabula scaffold + green CI.

See [fstec GUI migration status](https://github.com/butbeautifulv/fstec/blob/fstec/gui-detach-wip/docs/architecture/gui-migration-status.md) on the WIP branch.

## Related domains

| Domain | Repo | Role |
|--------|------|------|
| **Awareness** | [hexenhammer](../hexenhammer) | Phishing simulation (not part of Tabula) |
| **Knowledge** | [veil](../veil) | TI graph |
| **Pentest** | [veneno](../veneno) | Execution |
