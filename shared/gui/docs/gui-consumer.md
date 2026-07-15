# Consumer guide

This package is designed for the cxado meta-repo workflow (submodule + workspace link).

## Local (sibling folder) install

In the consumer app `package.json`:

```json
{
  "dependencies": {
    "@cxado/gui": "file:../cxado-gui"
  }
}
```

In the consumer `tsconfig.json`:

```json
{
  "compilerOptions": {
    "paths": {
      "@cxado/gui/*": ["../cxado-gui/src/*"]
    }
  }
}
```

In `app/globals.css`:

```css
@import "@cxado/gui/tailwind.preset.css";
```

## Style profiles

Primitives use semantic tokens (`rounded-gui-control`, `ring-gui-focus`, …) that switch between **radix-nova** (default) and **radix-lyra**.

| Consumer | Profile |
|----------|---------|
| FSTEC, Veil | default (nova) — no attribute |
| Egregore | `data-gui-style="lyra"` on `<html>` |

```tsx
<html lang="en" data-gui-style="lyra">
```

See [gui-style-profiles.md](gui-style-profiles.md) for the full token table.

## Meta-repo (recommended)

In [cys_framework](https://github.com/butbeautifulv/cxado):

```bash
git clone --recurse-submodules https://github.com/butbeautifulv/cxado.git
cd cxado
make bootstrap   # includes gui-link
```

`shared/gui` is a submodule of this repository. `make gui-link` symlinks
`node_modules/@cxado/gui` → `shared/gui` in pilot projects (Veil).

### Veil pilot

After `make gui-link` in the meta-repo:

```bash
cd projects/veil
# node_modules/@cxado/gui -> ../../shared/gui
```

Add to the consumer `tsconfig.json` (paths relative to project root):

```json
{
  "compilerOptions": {
    "paths": {
      "@cxado/gui/*": ["../../shared/gui/src/*"]
    }
  }
}
```

Alternative: `package.json` dependency `"@cxado/gui": "file:../../shared/gui"`.

### FSTEC

FSTEC currently uses sibling `file:../cxado-gui` for local dev. After submodule
checkout, optional path: `file:../../cys_framework/shared/gui`.

## Dashboard presentation

Inject app-specific labels and stat-card metadata:

```tsx
import { DashboardInteractive } from "@cxado/gui/dashboard/dashboard-interactive"
import { fstecCompliancePresentation } from "@/lib/cxado-gui/fstec-adapter"

<DashboardInteractive
  presentation={fstecCompliancePresentation}
  renderScopedTable={(ctx) => <AppScopedTable {...ctx} />}
  {...dataProps}
/>
```

FSTEC uses strangler re-exports under `@/components/dashboard/*` with wrappers
that pass `FSTEC_DASHBOARD_PRESENTATION` automatically.
