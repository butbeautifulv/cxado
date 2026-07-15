#!/usr/bin/env node
/** Replace remaining text-sm in ui/ with profile-aware text utilities. */
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const uiDir = join(dirname(fileURLToPath(import.meta.url)), "..", "src", "ui")

const skip = new Set(["typography.tsx", "card.tsx"])

const bodyFiles = new Set(["sheet.tsx", "empty.tsx"])

for (const entry of readdirSync(uiDir)) {
  if (!entry.endsWith(".tsx") || skip.has(entry)) continue
  const path = join(uiDir, entry)
  let content = readFileSync(path, "utf8")
  const token = bodyFiles.has(entry) ? "text-gui-body" : "text-gui-ui"
  const updated = content.replace(/\btext-sm\b/g, token)
  if (updated !== content) {
    writeFileSync(path, updated)
    console.log(`  ${entry}: text-sm → ${token}`)
  }
}
