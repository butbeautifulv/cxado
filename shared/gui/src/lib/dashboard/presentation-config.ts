import type { LucideIcon } from "lucide-react"

export type DashboardStatCardMeta = {
  hint: string
  icon: LucideIcon
  badge?: (value: number, total: number) => string | null
  badgeVariant?:
    | "default"
    | "secondary"
    | "destructive"
    | "outline"
    | "ghost"
    | "link"
}

/**
 * UI-only dashboard presentation config.
 * Consumers (apps) provide status order, colors, and stat-card metadata.
 */
export type DashboardPresentationConfig = {
  statusOrder: readonly string[]
  overdueStackOrder: readonly string[]
  statCardMeta: Record<string, DashboardStatCardMeta>
  chartEmptyLabel: string
  pieColors: readonly string[]
}
