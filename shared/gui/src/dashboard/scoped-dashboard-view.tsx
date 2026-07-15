"use client"

import type { Dispatch, SetStateAction, ReactNode } from "react"
import type { ColumnFiltersState } from "@tanstack/react-table"
import { ScopedDashboardCharts } from "./scoped-dashboard-charts"
import type { ScopedDashboardStats, DashboardScope } from "@cxado/gui/lib/dashboard/stats"
import {
  toggleBreakdownFilter,
  toggleStatusBreakdownFilter,
  toggleStatusFilter,
  type ChartFilterScope,
} from "@cxado/gui/lib/dashboard/chart-filters"
import type { DashboardPresentationConfig } from "@cxado/gui/lib/dashboard/presentation-config"
import type { ScopedTableRenderProps } from "@cxado/gui/lib/dashboard/interactive-props"
import type { PublicItem, PublicStatus } from "@cxado/gui/lib/public/types"
import type { DashboardMatrixRow } from "@cxado/gui/lib/dashboard/serialize-dashboard"
import type { DashboardVariant } from "@cxado/gui/lib/dashboard/variant-config"

type ScopedDashboardViewProps = {
  variant: DashboardVariant
  scope: ChartFilterScope
  dashboardScope: DashboardScope
  linkScope?: DashboardScope
  stats: ScopedDashboardStats
  items: DashboardMatrixRow[] | PublicItem[]
  token?: string
  statuses?: PublicStatus[]
  showSubdivisionColumn?: boolean
  columnFilters: ColumnFiltersState
  onColumnFiltersChange: Dispatch<SetStateAction<ColumnFiltersState>>
  visibleChartStatuses: ReadonlySet<string>
  presentation: DashboardPresentationConfig
  showCharts?: boolean
  showMatrix?: boolean
  renderScopedTable?: (ctx: ScopedTableRenderProps) => ReactNode
  scopedTableCtx: ScopedTableRenderProps
}

export function ScopedDashboardView({
  scope,
  stats,
  columnFilters,
  onColumnFiltersChange,
  visibleChartStatuses,
  presentation,
  showCharts = true,
  showMatrix = true,
  renderScopedTable,
  scopedTableCtx,
}: ScopedDashboardViewProps) {
  return (
    <>
      {showCharts ? (
        <ScopedDashboardCharts
          scope={scope}
          presentation={presentation}
          statusDistribution={stats.statusDistribution}
          statusBreakdown={stats.statusBreakdown}
          overdueTitle={stats.chartLabels.overdueTitle}
          completionTitle={stats.chartLabels.completionTitle}
          columnFilters={columnFilters}
          visibleChartStatuses={visibleChartStatuses}
          onStatusClick={(status) =>
            onColumnFiltersChange((prev) => toggleStatusFilter(prev, status))
          }
          onOverdueBarClick={(label) =>
            onColumnFiltersChange((prev) => toggleBreakdownFilter(prev, scope, label))
          }
          onStatusBreakdownClick={(label, status) =>
            onColumnFiltersChange((prev) =>
              toggleStatusBreakdownFilter(prev, scope, label, status)
            )
          }
        />
      ) : null}

      {showMatrix && renderScopedTable ? renderScopedTable(scopedTableCtx) : null}
    </>
  )
}
