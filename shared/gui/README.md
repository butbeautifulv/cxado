# @cxado/gui

Reusable UI kit for cxado compliance/cybersec projects (FSTEC, Veil, Veneno, …).

## Tiers

| Tier | Modules | Status |
|------|---------|--------|
| 1 | `ui/`, `shell/`, `motion/`, `skeletons/`, `data-table/`, `theme/`, `hooks/`, `utils` | Extracted from FSTEC |
| 2 | `layout/`, `forms/`, `charts/`, `columns/`, `tables/` | Extracted from FSTEC |
| 3 | `dashboard/` — `ComplianceDashboard` + presentation config types | Partial; data layer stays in apps |

## Install (local / meta-repo)

```bash
# In consumer app package.json (via make gui-link):
"@cxado/gui": "file:../../../shared/gui"

# tsconfig paths:
"@cxado/gui/*": ["../../../shared/gui/src/*"]
```

## cxado meta-repo

`shared/gui` is **in-tree** in cxado (not a separate repo). Link into pilots with `make gui-link`.

## CSS

Import in app `globals.css`:

```css
@import "@cxado/gui/tailwind.preset.css";
```

## Regenerate imports after sync from FSTEC

```bash
npm run rewrite-imports
```
