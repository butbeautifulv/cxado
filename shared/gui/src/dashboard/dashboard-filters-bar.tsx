"use client"

import { DashboardChartStatusFacetedFilter } from "./dashboard-chart-status-faceted-filter"
import {
  DashboardPeriodSection,
  DASHBOARD_PERIOD_LABELS,
} from "./dashboard-period-section"
import type { StatusDistribution } from "@cxado/gui/lib/dashboard/stats"
import type { PeriodBounds } from "@cxado/gui/lib/dashboard/period-range"
import type { DashboardPresentationConfig } from "@cxado/gui/lib/dashboard/presentation-config"

export function DashboardFiltersBar({
  periodBounds,
  presentation,
  statusDistribution,
  visibleChartStatuses,
  onVisibleChartStatusesChange,
}: {
  periodBounds: PeriodBounds
  presentation: DashboardPresentationConfig
  statusDistribution: StatusDistribution[]
  visibleChartStatuses: ReadonlySet<string>
  onVisibleChartStatusesChange: (next: Set<string>) => void
}) {
  return (
    <div className="flex flex-col gap-4 rounded-gui-control border bg-card p-4">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <DashboardPeriodSection
          bounds={periodBounds}
          embedded
          label={DASHBOARD_PERIOD_LABELS.orders}
        />
        <div className="flex shrink-0 items-center lg:pt-1">
          <DashboardChartStatusFacetedFilter
            presentation={presentation}
            statusDistribution={statusDistribution}
            visibleChartStatuses={visibleChartStatuses}
            onVisibleChartStatusesChange={onVisibleChartStatusesChange}
          />
        </div>
      </div>
    </div>
  )
}
