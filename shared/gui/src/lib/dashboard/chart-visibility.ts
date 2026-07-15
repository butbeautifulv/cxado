import type { StatusBreakdownRow } from "@cxado/gui/lib/charts/types"

export function isChartStatusVisible(
  visible: ReadonlySet<string>,
  status: string
): boolean {
  return visible.has(status)
}

export function visibleStatusesInOrder(
  order: readonly string[],
  visible: ReadonlySet<string>
): string[] {
  return order.filter((status) => visible.has(status))
}

export function canHideChartCategory(visible: ReadonlySet<string>): boolean {
  return visible.size > 1
}

export function hiddenChartStatusCount(
  visible: ReadonlySet<string>,
  order: readonly string[]
): number {
  return order.reduce((sum, status) => (visible.has(status) ? sum : sum + 1), 0)
}

export function setVisibleChartStatuses(
  visible: Set<string>,
  order: readonly string[]
): Set<string> {
  // ensure order items exist in set for stable downstream logic
  for (const status of order) {
    if (!visible.has(status) && visible.size === 0) visible.add(status)
  }
  return visible
}

export function sumVisibleBreakdown(
  row: StatusBreakdownRow,
  visible: ReadonlySet<string>,
  order: readonly string[]
): number {
  return order.reduce((sum, status) => {
    if (!isChartStatusVisible(visible, status)) return sum
    return sum + (row[status] ?? 0)
  }, 0)
}

export function sumVisibleBreakdownRows(
  rows: StatusBreakdownRow[],
  visible: ReadonlySet<string>,
  order: readonly string[]
): Record<string, number> {
  const totals = Object.fromEntries(order.map((status) => [status, 0])) as Record<
    string,
    number
  >
  for (const row of rows) {
    for (const status of order) {
      if (isChartStatusVisible(visible, status)) {
        totals[status] += row[status] ?? 0
      }
    }
  }
  return totals
}

export function visibleBreakdownGrandTotal(
  rows: StatusBreakdownRow[],
  visible: ReadonlySet<string>,
  order: readonly string[]
): number {
  return rows.reduce((sum, row) => sum + sumVisibleBreakdown(row, visible, order), 0)
}

export function defaultVisibleChartStatuses(order: readonly string[]): Set<string> {
  return new Set(order)
}

export function filterStatusDistribution<T extends { status: string }>(
  rows: T[],
  visible: ReadonlySet<string>
): T[] {
  return rows.filter((row) => visible.has(row.status))
}

