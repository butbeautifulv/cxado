# GUI style profiles

`@cxado/gui` primitives use **semantic style tokens** instead of hardcoded shadcn radix-nova classes (`rounded-lg`, `ring-3`, `text-sm`). Consumers pick a profile on `<html>` without post-sync regex scripts.

## Profiles

| Profile | Attribute | shadcn style | Used by |
|---------|-----------|--------------|---------|
| **nova** (default) | _(none)_ | `radix-nova` | FSTEC, Veil |
| **lyra** | `data-gui-style="lyra"` | `radix-lyra` | Egregore Operator UI |

## Setup

Import the preset in app `globals.css`:

```css
@import "@cxado/gui/tailwind.preset.css";
```

For Lyra consumers, set the profile on the document root:

```tsx
<html lang="en" data-gui-style="lyra" suppressHydrationWarning>
```

Colors and fonts remain app-owned (`shadcn apply` / `globals.css`). The preset only switches geometry and control typography.

## CSS variables

Defined in [`tailwind.preset.css`](../tailwind.preset.css):

| Variable | nova | lyra |
|----------|------|------|
| `--gui-radius-control` | `--radius-lg` | `0` |
| `--gui-radius-surface` | `--radius-xl` | `0` |
| `--gui-radius-muted` | `--radius-md` | `0` |
| `--gui-radius-pill` | `--radius-4xl` | `0` |
| `--gui-ring-focus` | `3px` | `1px` |
| `--gui-text-ui-size` | `0.875rem` | `0.75rem` |
| `--gui-text-control-size` | `1rem` → `0.875rem` at `md` | `0.75rem` |
| `--gui-primary-hover-opacity` | `0.9` | `0.8` |
| `--gui-card-footer-bg` | `muted/50` mix | transparent |

## Utility classes

| Class | Purpose |
|-------|---------|
| `rounded-gui-control` | Buttons, inputs, badges |
| `rounded-gui-surface` | Cards, dialogs, empty states |
| `rounded-gui-muted` | Tables, tooltips, skeletons |
| `rounded-gui-pill` | Badge pill radius |
| `rounded-gui-compact` / `rounded-gui-compact-sm` | Button `xs` / `sm` sizes |
| `ring-gui-focus` | Focus and invalid rings |
| `text-gui-control` | Inputs, textareas |
| `text-gui-ui` | Buttons, labels, menus |
| `text-gui-body` | Card/sheet body copy |
| `text-gui-card-title` | Card/sheet/dialog titles |
| `hover:bg-primary/[var(--gui-primary-hover-opacity)]` | Primary hover |
| `bg-gui-card-footer` | Card footer background |

## TypeScript helpers

```ts
import { gui } from "@cxado/gui/lib/gui-style"

cn(gui.roundedControl, gui.ringFocus, gui.textUi)
```

## Regenerating primitives from FSTEC

After syncing from FSTEC, run:

```bash
npm run apply-gui-style-tokens
```

This reapplies semantic tokens if shadcn output reintroduces `rounded-lg` / `ring-3`.

## Guard

```bash
npm run check-gui-style-tokens
```

Fails if forbidden nova tokens remain under `src/ui/`.
