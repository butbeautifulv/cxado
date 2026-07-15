"use client"

import { useCallback, useMemo, useState, type ReactNode } from "react"
import type { ColumnFiltersState } from "@tanstack/react-table"
import { DashboardFiltersBar } from "./dashboard-filters-bar"
import { DashboardStatCards } from "./dashboard-stat-cards"
import { ScopedDashboardView } from "./scoped-dashboard-view"
import {
  overdueInitialFilters,
  toggleDashboardStatusFilter,
  isDashboardStatusFilterActive,
} from "@cxado/gui/lib/dashboard/chart-filters"
import {
  defaultVisibleChartStatuses,
  setVisibleChartStatuses as applyVisibleChartStatuses,
} from "@cxado/gui/lib/dashboard/chart-visibility"
import type { DashboardPresentationConfig } from "@cxado/gui/lib/dashboard/presentation-config"
import type {
  DashboardInteractiveProps,
  ScopedTableRenderProps,
} from "@cxado/gui/lib/dashboard/interactive-props"
import type { PeriodBounds } from "@cxado/gui/lib/dashboard/period-range"

export type { DashboardInteractiveProps } from "@cxado/gui/lib/dashboard/interactive-props"
export type { DashboardVariant } from "@cxado/gui/lib/dashboard/variant-config"

function activeDashboardStatusFromFilters(
  filters: ColumnFiltersState,
  statusOrder: readonly string[]
): string | undefined {
  for (const status of statusOrder) {
    if (isDashboardStatusFilterActive(filters, status)) return status
  }
  return undefined
}

export function DashboardInteractive({
  presentation,
  renderScopedTable,
  showStatCards = true,
  showCharts = true,
  showMatrix = true,
  periodBounds,
  ...props
}: DashboardInteractiveProps & {
  presentation: DashboardPresentationConfig
  renderScopedTable?: (ctx: ScopedTableRenderProps) => ReactNode
  showStatCards?: boolean
  showCharts?: boolean
  showMatrix?: boolean
  periodBounds?: PeriodBounds
}) {
  const { stats, overdueOnly } = props
  const initialFilters = useMemo(
    () => (overdueOnly ? overdueInitialFilters() : []),
    [overdueOnly]
  )
  const [columnFilters, setColumnFilters] =
    useState<ColumnFiltersState>(initialFilters)
  const [visibleChartStatuses, setVisibleChartStatuses] = useState(() =>
    defaultVisibleChartStatuses(presentation.statusOrder)
  )

  const handleVisibleChartStatusesChange = useCallback(
    (next: Set<string>) => {
      setVisibleChartStatuses(
        applyVisibleChartStatuses(next, presentation.statusOrder)
      )
    },
    [presentation.statusOrder]
  )

  const activeStatus = activeDashboardStatusFromFilters(
    columnFilters,
    presentation.statusOrder
  )

  const scopedTableCtx: ScopedTableRenderProps = {
    ...props,
    columnFilters,
    onColumnFiltersChange: setColumnFilters,
  }

  return (
    <>
      {showStatCards ? (
        <DashboardStatCards
          stats={stats}
          presentation={presentation}
          activeStatus={activeStatus}
          onStatusClick={(status) =>
            setColumnFilters((prev) => toggleDashboardStatusFilter(prev, status))
          }
        />
      ) : null}

      {periodBounds ? (
        <DashboardFiltersBar
          periodBounds={periodBounds}
          presentation={presentation}
          statusDistribution={stats.statusDistribution}
          visibleChartStatuses={visibleChartStatuses}
          onVisibleChartStatusesChange={handleVisibleChartStatusesChange}
        />
      ) : null}

      {showCharts || (showMatrix && renderScopedTable) ? (
        <ScopedDashboardView
          {...props}
          presentation={presentation}
          columnFilters={columnFilters}
          onColumnFiltersChange={setColumnFilters}
          visibleChartStatuses={visibleChartStatuses}
          showCharts={showCharts}
          showMatrix={showMatrix}
          renderScopedTable={renderScopedTable}
          scopedTableCtx={scopedTableCtx}
        />
      ) : null}
    </>
  )
}
