"use client"

import { Bar, BarChart, CartesianGrid, Cell, LabelList, XAxis, YAxis } from "recharts"
import type { ColumnFiltersState } from "@tanstack/react-table"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@cxado/gui/ui/chart"
import {
  ChartCategoryViewport,
  type ChartSize,
} from "@cxado/gui/charts/chart-category-viewport"
import {
  DashboardChartLayout,
  DashboardChartLegend,
  StackedBarSegmentLabel,
  WrappedXAxisTick,
  barChartContainerClassName,
  formatChartLegendLabel,
  hasBreakdownFilter,
  hasStatusFilter,
  INACTIVE_OPACITY,
  ChartEmptyState,
} from "@cxado/gui/charts/dashboard-chart-shared"
import { MotionFadeIn } from "@cxado/gui/motion"
import type { StatusBreakdownRow, StatusDistribution } from "@cxado/gui/lib/charts/types"
import {
  isBreakdownFilterActive,
  isStatusFilterActive,
  isStatusSegmentHighlighted,
} from "@cxado/gui/lib/dashboard/chart-filters"
import type { ChartFilterScope } from "@cxado/gui/lib/charts/types"
import {
  isChartStatusVisible,
  sumVisibleBreakdownRows,
  visibleBreakdownGrandTotal,
  visibleStatusesInOrder,
} from "@cxado/gui/lib/dashboard/chart-visibility"

export type StackedBreakdownChartVariant = "completion" | "overdue"

export function StackedStatusBreakdownChart({
  scope,
  statusDistribution,
  statusBreakdown,
  stackOrder,
  legendOrder,
  columnFilters = [],
  visibleChartStatuses,
  onOverdueBarClick,
  onStatusBreakdownClick,
  size = "card",
  variant = "completion",
  showEmptyState = false,
}: {
  scope: ChartFilterScope
  statusDistribution: StatusDistribution[]
  statusBreakdown: StatusBreakdownRow[]
  stackOrder: readonly string[]
  legendOrder: readonly string[]
  columnFilters?: ColumnFiltersState
  visibleChartStatuses: ReadonlySet<string>
  onOverdueBarClick?: (label: string) => void
  onStatusBreakdownClick?: (label: string, status: string) => void
  size?: ChartSize
  variant?: StackedBreakdownChartVariant
  showEmptyState?: boolean
}) {
  const statusColorMap = Object.fromEntries(
    statusDistribution.map((d) => [d.status, d.fill])
  )

  const visibleStatuses = visibleStatusesInOrder(stackOrder, visibleChartStatuses)

  const statusBreakdownConfig = legendOrder.reduce<ChartConfig>((acc, status) => {
    acc[status] = {
      label: status,
      color: statusColorMap[status] ?? "var(--chart-1)",
    }
    return acc
  }, {})

  const breakdownFilterActive = hasBreakdownFilter(columnFilters, scope)
  const statusFilterActive = hasStatusFilter(columnFilters)

  const legendStatuses = legendOrder

  const statusTotals = sumVisibleBreakdownRows(
    statusBreakdown,
    visibleChartStatuses,
    legendStatuses
  )

  const legendGrandTotal = visibleBreakdownGrandTotal(
    statusBreakdown,
    visibleChartStatuses,
    legendStatuses
  )

  const legendItems = legendStatuses.map((status) => ({
    key: status,
    label: formatChartLegendLabel(
      status,
      isChartStatusVisible(visibleChartStatuses, status) ? statusTotals[status] : 0,
      legendGrandTotal
    ),
    color: statusColorMap[status] ?? "var(--chart-1)",
    visible: isChartStatusVisible(visibleChartStatuses, status),
    active: isStatusFilterActive(columnFilters, status),
  }))

  const categoryCount = statusBreakdown.length
  const compactLabels = categoryCount > 5
  const isCompletion = variant === "completion"

  const chart = (
    <ChartCategoryViewport
      categoryCount={categoryCount}
      size={size}
      variant={isCompletion ? "completion" : undefined}
      plotAreaInsets={isCompletion ? { left: 52, right: 40 } : undefined}
    >
      {(layout, chartWidth) => (
        <ChartContainer
          config={statusBreakdownConfig}
          className={barChartContainerClassName(layout, size)}
          initialDimension={
            chartWidth
              ? {
                  width: chartWidth,
                  height: isCompletion
                    ? layout.completionInitial.height
                    : layout.overdueInitial.height,
                }
              : isCompletion
                ? layout.completionInitial
                : layout.overdueInitial
          }
        >
          <BarChart
            data={statusBreakdown}
            barCategoryGap={layout.barCategoryGap}
            barGap={isCompletion && categoryCount <= 5 ? 3 : isCompletion ? 2 : undefined}
            maxBarSize={layout.maxBarSize}
            margin={{
              top: 14,
              right: isCompletion ? 40 : 12,
              left: isCompletion ? 12 : 8,
              bottom: layout.chartMarginBottom,
            }}
          >
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="label"
              tickLine={false}
              axisLine={false}
              interval={0}
              height={layout.xAxisHeight}
              tick={({ x, y, payload }) => (
                <WrappedXAxisTick
                  x={Number(x)}
                  y={Number(y)}
                  payload={payload}
                  maxCharsPerLine={layout.xLabelChars}
                  maxLines={layout.xLabelLines}
                  maxTickWidth={layout.maxTickWidth}
                  active={isBreakdownFilterActive(
                    columnFilters,
                    scope,
                    String(payload?.value ?? "")
                  )}
                  onClick={onOverdueBarClick}
                />
              )}
            />
            {isCompletion ? (
              <YAxis tickLine={false} axisLine={false} />
            ) : (
              <YAxis type="number" hide />
            )}
            <ChartTooltip content={<ChartTooltipContent />} />
            {visibleStatuses.map((status, index) => {
              const isLast = index === visibleStatuses.length - 1
              const isFirst = index === 0
              const statusIndex = legendStatuses.indexOf(status)
              const firstRadius: [number, number, number, number] = isCompletion
                ? [0, 0, 0, 0]
                : [0, 0, 4, 4]

              return (
                <Bar
                  key={status}
                  dataKey={status}
                  stackId="status"
                  minPointSize={categoryCount > 5 ? 0 : 8}
                  fill={
                    statusColorMap[status] ??
                    `var(--chart-${statusIndex + 1})`
                  }
                  radius={isLast ? [4, 4, 0, 0] : isFirst ? firstRadius : [0, 0, 0, 0]}
                  className="cursor-pointer"
                  onClick={(data) => {
                    const payload = data as { label?: string }
                    if (payload.label && onStatusBreakdownClick) {
                      onStatusBreakdownClick(payload.label, status)
                    }
                  }}
                >
                  {statusBreakdown.map((entry) => {
                    const highlighted = isStatusSegmentHighlighted(
                      columnFilters,
                      scope,
                      entry.label,
                      status
                    )
                    const dimmed =
                      (breakdownFilterActive || statusFilterActive) && !highlighted
                    return (
                      <Cell
                        key={`${entry.label}-${status}`}
                        fillOpacity={dimmed ? INACTIVE_OPACITY : 1}
                        stroke={highlighted ? "var(--foreground)" : undefined}
                        strokeWidth={highlighted ? 1 : 0}
                      />
                    )
                  })}
                  <LabelList
                    dataKey={status}
                    content={
                      ((props: Record<string, unknown>) => (
                        <StackedBarSegmentLabel
                          {...props}
                          compact={
                            isCompletion
                              ? compactLabels
                              : compactLabels || layout.maxTickWidth != null
                          }
                        />
                      )) as never
                    }
                  />
                </Bar>
              )
            })}
          </BarChart>
        </ChartContainer>
      )}
    </ChartCategoryViewport>
  )

  if (showEmptyState && statusBreakdown.length === 0) {
    return <ChartEmptyState />
  }

  return (
    <MotionFadeIn className="h-full">
      <DashboardChartLayout
        size={size}
        chart={chart}
        legend={<DashboardChartLegend items={legendItems} />}
      />
    </MotionFadeIn>
  )
}
