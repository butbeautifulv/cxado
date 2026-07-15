"use client"

import type { ColumnFiltersState } from "@tanstack/react-table"
import { StackedStatusBreakdownChart } from "@cxado/gui/charts/stacked-status-breakdown-chart"
import type { ChartSize } from "@cxado/gui/charts/chart-category-viewport"
import type { StatusBreakdownRow, StatusDistribution } from "@cxado/gui/lib/dashboard/stats"
import type { ChartFilterScope } from "@cxado/gui/lib/dashboard/chart-filters"
import type { DashboardPresentationConfig } from "@cxado/gui/lib/dashboard/presentation-config"

export function OverdueBreakdownChartSection({
  scope,
  presentation,
  statusDistribution,
  statusBreakdown,
  columnFilters = [],
  visibleChartStatuses,
  onOverdueBarClick,
  onStatusBreakdownClick,
  size = "card",
}: {
  scope: ChartFilterScope
  presentation: DashboardPresentationConfig
  statusDistribution: StatusDistribution[]
  statusBreakdown: StatusBreakdownRow[]
  columnFilters?: ColumnFiltersState
  visibleChartStatuses: ReadonlySet<string>
  onOverdueBarClick?: (label: string) => void
  onStatusBreakdownClick?: (label: string, status: string) => void
  size?: ChartSize
}) {
  const { statusOrder, overdueStackOrder } = presentation

  return (
    <StackedStatusBreakdownChart
      scope={scope}
      statusDistribution={statusDistribution}
      statusBreakdown={statusBreakdown}
      stackOrder={overdueStackOrder}
      legendOrder={statusOrder}
      columnFilters={columnFilters}
      visibleChartStatuses={visibleChartStatuses}
      onOverdueBarClick={onOverdueBarClick}
      onStatusBreakdownClick={onStatusBreakdownClick}
      size={size}
      variant="overdue"
      showEmptyState
    />
  )
}
