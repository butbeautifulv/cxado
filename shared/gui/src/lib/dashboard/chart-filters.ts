import type { ColumnFiltersState } from "@tanstack/react-table"
import type { ChartFilterScope } from "@cxado/gui/lib/charts/types"

export type { ChartFilterScope }

export function breakdownColumnId(scope: ChartFilterScope): string {
  switch (scope) {
    case "global":
      return "organization"
    case "organization":
      return "subdivisionName"
    case "subdivision":
      return "orderTitle"
  }
}

export function overdueInitialFilters(): ColumnFiltersState {
  return [{ id: "status", value: ["Просрочено"] }]
}

function filterValues(filters: ColumnFiltersState, id: string): string[] {
  return (filters.find((f) => f.id === id)?.value as string[]) ?? []
}

function setFilter(
  filters: ColumnFiltersState,
  id: string,
  values: string[] | undefined
): ColumnFiltersState {
  const rest = filters.filter((f) => f.id !== id)
  if (!values?.length) return rest
  return [...rest, { id, value: values }]
}

function arraysEqual(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false
  const sortedA = [...a].sort()
  const sortedB = [...b].sort()
  return sortedA.every((v, i) => v === sortedB[i])
}

export function dashboardStatusFilterValues(status: string): string[] {
  return [status]
}

export function isDashboardStatusFilterActive(
  filters: ColumnFiltersState,
  displayStatus: string
): boolean {
  return arraysEqual(
    [...filterValues(filters, "status")].sort(),
    [...dashboardStatusFilterValues(displayStatus)].sort()
  )
}

export function toggleDashboardStatusFilter(
  filters: ColumnFiltersState,
  displayStatus: string
): ColumnFiltersState {
  const values = dashboardStatusFilterValues(displayStatus)
  const current = filterValues(filters, "status")
  if (arraysEqual([...current].sort(), [...values].sort())) {
    return setFilter(filters, "status", undefined)
  }
  const withoutBreakdown = filters.filter(
    (f) =>
      f.id !== "organization" &&
      f.id !== "subdivisionName" &&
      f.id !== "orderTitle"
  )
  return setFilter(withoutBreakdown, "status", values)
}

export function toggleStatusFilter(
  filters: ColumnFiltersState,
  status: string
): ColumnFiltersState {
  const current = filterValues(filters, "status")
  if (current.length === 1 && current[0] === status) {
    return setFilter(filters, "status", undefined)
  }
  const withoutBreakdown = filters.filter(
    (f) =>
      f.id !== "organization" &&
      f.id !== "subdivisionName" &&
      f.id !== "orderTitle"
  )
  return setFilter(withoutBreakdown, "status", [status])
}

export function toggleBreakdownFilter(
  filters: ColumnFiltersState,
  scope: ChartFilterScope,
  label: string
): ColumnFiltersState {
  const columnId = breakdownColumnId(scope)
  const current = filterValues(filters, columnId)
  if (current.length === 1 && current[0] === label) {
    return setFilter(filters, columnId, undefined)
  }
  const withoutStatus = setFilter(filters, "status", undefined)
  return setFilter(withoutStatus, columnId, [label])
}

export function toggleStatusBreakdownFilter(
  filters: ColumnFiltersState,
  scope: ChartFilterScope,
  label: string,
  status: string
): ColumnFiltersState {
  const columnId = breakdownColumnId(scope)
  const breakdownCurrent = filterValues(filters, columnId)
  const statusCurrent = filterValues(filters, "status")

  if (
    breakdownCurrent.length === 1 &&
    breakdownCurrent[0] === label &&
    statusCurrent.length === 1 &&
    statusCurrent[0] === status
  ) {
    return filters.filter((f) => f.id !== columnId && f.id !== "status")
  }

  const rest = filters.filter((f) => f.id !== columnId && f.id !== "status")
  return [
    ...rest,
    { id: columnId, value: [label] },
    { id: "status", value: [status] },
  ]
}

export function isStatusFilterActive(
  filters: ColumnFiltersState,
  status: string
): boolean {
  return isDashboardStatusFilterActive(filters, status)
}

export function hasBreakdownFilter(
  filters: ColumnFiltersState,
  scope: ChartFilterScope
): boolean {
  return filters.some((f) => f.id === breakdownColumnId(scope))
}

export function isBreakdownFilterActive(
  filters: ColumnFiltersState,
  scope: ChartFilterScope,
  label: string
): boolean {
  const columnId = breakdownColumnId(scope)
  const f = filters.find((x) => x.id === columnId)
  const values = (f?.value as string[] | undefined) ?? []
  return values.includes(label)
}

export function isStatusSegmentHighlighted(
  filters: ColumnFiltersState,
  scope: ChartFilterScope,
  label: string,
  status: string
): boolean {
  const statusActive = isStatusFilterActive(filters, status)
  const breakdownActive = isBreakdownFilterActive(filters, scope, label)
  const hasStatus = filters.some((f) => f.id === "status")
  const hasBreakdown = hasBreakdownFilter(filters, scope)
  if (!hasStatus && !hasBreakdown) return true
  if (hasStatus && hasBreakdown) return statusActive && breakdownActive
  if (hasStatus) return statusActive
  return breakdownActive
}
