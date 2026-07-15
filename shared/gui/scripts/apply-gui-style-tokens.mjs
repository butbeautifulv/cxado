#!/usr/bin/env node
/**
 * Replace hardcoded radix-nova class tokens with semantic GUI profile utilities.
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "src")

function walk(dir) {
  const out = []
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry)
    if (statSync(path).isDirectory()) out.push(...walk(path))
    else if (/\.(ts|tsx)$/.test(entry)) out.push(path)
  }
  return out
}

const replacements = [
  ["focus-visible:ring-[3px]", "focus-visible:ring-gui-focus"],
  ["focus-visible:ring-3", "focus-visible:ring-gui-focus"],
  ["aria-invalid:ring-3", "aria-invalid:ring-gui-focus"],
  ["has-[[data-slot=input-group-control]:focus-visible]:ring-3", "has-[[data-slot=input-group-control]:focus-visible]:ring-gui-focus"],
  ["has-[[data-slot][aria-invalid=true]]:ring-3", "has-[[data-slot][aria-invalid=true]]:ring-gui-focus"],
  ["rounded-[min(var(--radius-md),10px)]", "rounded-gui-compact"],
  ["rounded-[min(var(--radius-md),12px)]", "rounded-gui-compact-sm"],
  ["in-data-[slot=button-group]:rounded-lg", "in-data-[slot=button-group]:rounded-gui-control"],
  ["rounded-t-xl", "rounded-t-gui-surface"],
  ["rounded-b-xl", "rounded-b-gui-surface"],
  ["rounded-4xl", "rounded-gui-pill"],
  ["rounded-xl!", "rounded-gui-surface!"],
  ["rounded-xl", "rounded-gui-surface"],
  ["rounded-lg!", "rounded-gui-control!"],
  ["rounded-lg", "rounded-gui-control"],
  ["rounded-md", "rounded-gui-muted"],
  ["rounded-[4px]", "rounded-gui-checkbox"],
  ["hover:bg-primary/90", "hover:bg-primary/[var(--gui-primary-hover-opacity)]"],
  ["text-sm/relaxed", "text-gui-body"],
  ["text-base md:text-sm", "text-gui-control"],
  ["file:text-sm", "file:text-gui-ui"],
]

const files = walk(root)
let changed = 0

for (const path of files) {
  let content = readFileSync(path, "utf8")
  const original = content
  for (const [from, to] of replacements) {
    content = content.replaceAll(from, to)
  }
  if (content !== original) {
    writeFileSync(path, content)
    changed++
    console.log(`  updated ${path.slice(root.length + 1)}`)
  }
}

console.log(`Applied GUI style tokens to ${changed} files.`)
