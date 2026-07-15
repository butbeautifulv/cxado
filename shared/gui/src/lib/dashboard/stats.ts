import type { StatusBreakdownRow, StatusDistribution } from "@cxado/gui/lib/charts/types"

export type { StatusDistribution, StatusBreakdownRow }

export type DashboardDateRange = {
  issuedFrom?: Date
  issuedTo?: Date
}

export type DashboardScope =
  | ({ type: "global" } & DashboardDateRange)
  | ({ type: "organization"; organizationId: number } & DashboardDateRange)
  | ({
      type: "subdivision"
      organizationId: number
      subdivisionId: number
    } & DashboardDateRange)

export type ScopedDashboardStats = {
  scope: DashboardScope["type"]
  statusDistribution: StatusDistribution[]
  overdueBreakdown: { label: string; count: number; total: number }[]
  statusBreakdown: StatusBreakdownRow[]
  chartLabels: {
    overdueTitle: string
    completionTitle: string
  }
}
