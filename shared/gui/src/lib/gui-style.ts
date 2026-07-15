/**
 * Semantic GUI style class names — switch profiles via html[data-gui-style].
 * Default: radix-nova. Lyra: data-gui-style="lyra".
 */
export const gui = {
  roundedControl: "rounded-gui-control",
  roundedSurface: "rounded-gui-surface",
  roundedTopSurface: "rounded-t-gui-surface",
  roundedBottomSurface: "rounded-b-gui-surface",
  roundedMuted: "rounded-gui-muted",
  roundedPill: "rounded-gui-pill",
  roundedCompact: "rounded-gui-compact",
  roundedCompactSm: "rounded-gui-compact-sm",
  roundedCheckbox: "rounded-gui-checkbox",
  ringFocus: "ring-gui-focus",
  textControl: "text-gui-control",
  textUi: "text-gui-ui",
  textBody: "text-gui-body",
  textCardTitle: "text-gui-card-title",
  hoverPrimary: "hover:bg-primary/[var(--gui-primary-hover-opacity)]",
  bgCardFooter: "bg-gui-card-footer",
  buttonGroupControl: "in-data-[slot=button-group]:rounded-gui-control",
} as const
