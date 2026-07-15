#!/usr/bin/env node
/** Fail if hardcoded radix-nova style tokens remain in src/ui/. */
import { readFileSync, readdirSync, statSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const uiDir = join(dirname(fileURLToPath(import.meta.url)), "..", "src", "ui")

const FORBIDDEN = [
  /\brounded-lg\b/,
  /\brounded-md\b/,
  /\brounded-xl\b/,
  /\brounded-4xl\b/,
  /\bring-3\b/,
  /\bring-\[3px\]\b/,
  /\bhover:bg-primary\/90\b/,
]

function walk(dir) {
  const out = []
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry)
    if (statSync(path).isDirectory()) out.push(...walk(path))
    else if (entry.endsWith(".tsx")) out.push(path)
  }
  return out
}

const violations = []
for (const path of walk(uiDir)) {
  const content = readFileSync(path, "utf8")
  const rel = path.slice(uiDir.length + 1)
  for (const pattern of FORBIDDEN) {
    if (pattern.test(content)) {
      violations.push(`${rel}: ${pattern}`)
    }
  }
}

if (violations.length > 0) {
  console.error("Forbidden nova tokens in src/ui/:")
  for (const v of violations) console.error(`  ${v}`)
  process.exit(1)
}

console.log("GUI style token guard passed.")
