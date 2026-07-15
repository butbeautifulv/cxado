import { readFileSync, writeFileSync } from "node:fs"
import { globSync } from "node:glob"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "src")

const replacements = [
  [/@\/components\/ui\//g, "@cxado/gui/ui/"],
  [/@\/components\/shell\//g, "@cxado/gui/shell/"],
  [/@\/components\/motion/g, "@cxado/gui/motion"],
  [/@\/components\/shared\/skeletons\//g, "@cxado/gui/skeletons/"],
  [/@\/components\/data-table/g, "@cxado/gui/data-table"],
  [/@\/components\/theme-provider/g, "@cxado/gui/theme/theme-provider"],
  [/@\/components\/theme-toggle/g, "@cxado/gui/theme/theme-toggle"],
  [/@\/components\/theme-hotkey/g, "@cxado/gui/theme/theme-hotkey"],
  [/@\/lib\/theme\/blocking-script/g, "@cxado/gui/theme/blocking-script"],
  [/@\/lib\/utils/g, "@cxado/gui/utils"],
  [/@\/hooks\/use-mobile/g, "@cxado/gui/hooks/use-mobile"],
  [/@\/hooks\/use-compact-shell/g, "@cxado/gui/hooks/use-compact-shell"],
  [/@\/lib\/data-table\//g, "@cxado/gui/lib/data-table/"],
  [/@\/components\/shared\/overflow-text/g, "@cxado/gui/layout/overflow-text"],
  [/@\/components\/shared\/page-header/g, "@cxado/gui/layout/page-header"],
  [/@\/components\/shared\/form-card-grid/g, "@cxado/gui/layout/form-card-grid"],
  [/@\/components\/shared\/form-actions-bar/g, "@cxado/gui/layout/form-actions-bar"],
  [/@\/components\/shared\/share-link-field/g, "@cxado/gui/layout/share-link-field"],
  [/@\/components\/shared\/share-link-actions/g, "@cxado/gui/layout/share-link-actions"],
  [/@\/components\/shared\/commentary-attachments-field/g, "@cxado/gui/forms/commentary-attachments-field"],
  [/@\/components\/dashboard\/dashboard-chart-shared/g, "@cxado/gui/charts/dashboard-chart-shared"],
  [/@\/components\/dashboard\/chart-category-viewport/g, "@cxado/gui/charts/chart-category-viewport"],
  [/@\/components\/dashboard\/chart-card-layout/g, "@cxado/gui/charts/chart-card-layout"],
  [/@\/components\/dashboard\/stacked-status-breakdown-chart/g, "@cxado/gui/charts/stacked-status-breakdown-chart"],
  [/@\/lib\/ui\/table-labels/g, "@cxado/gui/lib/ui/table-labels"],
  [/@\/lib\/ui\/tracked-item-types/g, "@cxado/gui/lib/ui/tracked-item-types"],
  [/@\/components\/shared\/tracked-items-data-table/g, "@cxado/gui/tables/tracked-items-data-table"],
]

for (const file of globSync("**/*.{ts,tsx}", { cwd: root })) {
  const path = join(root, file)
  let content = readFileSync(path, "utf8")
  for (const [from, to] of replacements) {
    content = content.replace(from, to)
  }
  writeFileSync(path, content)
}

console.log(`Rewrote imports in ${globSync("**/*.{ts,tsx}", { cwd: root }).length} files`)
