"use client"

import { Cell, Pie, PieChart } from "recharts"
import type { ColumnFiltersState } from "@tanstack/react-table"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@cxado/gui/ui/chart"
import {
  DashboardChartLayout,
  PieSliceLabel,
  DashboardChartLegend,
  buildFullDistribution,
  chartMetrics,
  formatChartLegendLabel,
  hasStatusFilter,
  INACTIVE_OPACITY,
} from "@cxado/gui/charts/dashboard-chart-shared"
import { MotionFadeIn } from "@cxado/gui/motion"
import type { ChartSize } from "@cxado/gui/charts/chart-category-viewport"
import { cn } from "@cxado/gui/utils"
import { isStatusFilterActive } from "@cxado/gui/lib/dashboard/chart-filters"
import {
  filterStatusDistribution,
  isChartStatusVisible,
} from "@cxado/gui/lib/dashboard/chart-visibility"
import type { StatusDistribution } from "@cxado/gui/lib/dashboard/stats"
import type { DashboardPresentationConfig } from "@cxado/gui/lib/dashboard/presentation-config"

export function StatusPieChartSection({
  statusDistribution,
  presentation,
  columnFilters = [],
  visibleChartStatuses,
  onStatusClick,
  size = "card",
}: {
  statusDistribution: StatusDistribution[]
  presentation: DashboardPresentationConfig
  columnFilters?: ColumnFiltersState
  visibleChartStatuses: ReadonlySet<string>
  onStatusClick?: (status: string) => void
  size?: ChartSize
}) {
  const fullDistribution = buildFullDistribution(
    statusDistribution,
    presentation.statusOrder,
    presentation.pieColors
  )
  const visibleDistribution = filterStatusDistribution(
    fullDistribution,
    visibleChartStatuses
  )

  const statusChartConfig = fullDistribution.reduce<ChartConfig>((acc, row, i) => {
    acc[row.status] = {
      label: row.status,
      color: row.fill ?? `var(--chart-${(i % 5) + 1})`,
    }
    return acc
  }, { count: { label: "Количество" } })

  const statusFilterActive = hasStatusFilter(columnFilters)
  const statusTotal = visibleDistribution.reduce((s, r) => s + r.count, 0)
  const metrics = chartMetrics(size)
  const isCard = size === "card"

  const statusLegendItems = fullDistribution.map((entry) => ({
    key: entry.status,
    label: formatChartLegendLabel(
      entry.status,
      isChartStatusVisible(visibleChartStatuses, entry.status) ? entry.count : 0,
      statusTotal
    ),
    color: entry.fill,
    visible: isChartStatusVisible(visibleChartStatuses, entry.status),
    active: isStatusFilterActive(columnFilters, entry.status),
  }))

  const chart = (
    <MotionFadeIn className="h-full w-full">
      <div
        className={cn(
          "relative mx-auto",
          isCard ? "flex h-full w-full items-center justify-center" : "w-full"
        )}
      >
      <div
        className={cn(
          "relative",
          isCard
            ? "aspect-square h-full max-h-full"
            : cn("mx-auto aspect-square w-full", metrics.pieMaxH)
        )}
      >
        <ChartContainer
          config={statusChartConfig}
          className={cn("aspect-square h-full w-full", !isCard && metrics.pieMaxH)}
          initialDimension={
            size === "expanded" ? { width: 480, height: 480 } : undefined
          }
        >
          <PieChart margin={{ top: 12, right: 20, bottom: 12, left: 20 }}>
            <ChartTooltip content={<ChartTooltipContent hideLabel />} />
            <Pie
              data={visibleDistribution}
              dataKey="count"
              nameKey="status"
              cx="50%"
              cy="50%"
              innerRadius="40%"
              outerRadius={metrics.pieOuterRadius}
              strokeWidth={2}
              className="cursor-pointer"
              label={PieSliceLabel}
              labelLine={false}
              onClick={(_, index) => {
                const entry = visibleDistribution[index]
                if (entry && onStatusClick) onStatusClick(entry.status)
              }}
            >
              {visibleDistribution.map((entry) => {
                const active = isStatusFilterActive(columnFilters, entry.status)
                const dimmed = statusFilterActive && !active
                return (
                  <Cell
                    key={entry.status}
                    fill={entry.fill}
                    fillOpacity={dimmed ? INACTIVE_OPACITY : 1}
                    stroke={active ? "var(--foreground)" : undefined}
                    strokeWidth={active ? 2 : 0}
                  />
                )
              })}
            </Pie>
          </PieChart>
        </ChartContainer>
        <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <span className={cn("font-bold tabular-nums", metrics.pieCenterClass)}>
            {statusTotal}
          </span>
        </div>
      </div>
    </div>
    </MotionFadeIn>
  )

  return (
    <DashboardChartLayout
      size={size}
      chart={chart}
      legend={<DashboardChartLegend items={statusLegendItems} />}
    />
  )
}
