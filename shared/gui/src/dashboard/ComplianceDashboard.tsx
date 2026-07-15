import type { LucideIcon } from "lucide-react"
import type { ReactNode } from "react"

export type ComplianceStatCardMeta = {
  hint: string
  icon: LucideIcon
  badge?: (value: number, total: number) => string | null
  badgeVariant?: "default" | "secondary" | "destructive" | "outline" | "ghost" | "link"
}

export type CompliancePresentationConfig = {
  statusOrder: readonly string[]
  overdueStackOrder: readonly string[]
  statCardMeta: Record<string, ComplianceStatCardMeta>
  chartEmptyLabel: string
  pieColors: readonly string[]
}

export type ComplianceStatusDistribution = {
  status: string
  count: number
  fill: string
}

export type ComplianceDashboardStats = {
  statusDistribution: ComplianceStatusDistribution[]
}

export type ComplianceLinkTargets<TRow> = {
  organization: (orgId: number) => string
  subdivision?: (orgId: number, subId: number) => string
  order: (orderId: number) => string
  measure: (row: TRow) => string
}

export type ComplianceDashboardProps<TRow> = {
  presentation: CompliancePresentationConfig
  stats: ComplianceDashboardStats
  children?: ReactNode
  header?: ReactNode
  charts?: ReactNode
  matrix?: ReactNode
}

/** Orchestrator shell — apps compose charts/matrix via slots until full decoupling. */
export function ComplianceDashboard<TRow>({
  header,
  charts,
  matrix,
  children,
}: ComplianceDashboardProps<TRow>) {
  return (
    <div className="flex flex-col gap-4 md:gap-6">
      {header}
      {charts}
      {matrix}
      {children}
    </div>
  )
}
