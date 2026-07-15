"use client"

import { useMemo } from "react"
import type { ColumnDef, ColumnFiltersState } from "@tanstack/react-table"
import { DataTable } from "@cxado/gui/data-table"
import { EmptyTableState } from "@cxado/gui/layout/empty-table-state"
import {
  createDueAtColumn,
  createMatrixWorkflowStatusColumn,
  createMeasureColumn,
  createOrderColumn,
  createOrganizationColumn,
} from "@cxado/gui/columns"
import { createSubdivisionColumn } from "@cxado/gui/columns/subdivision-column"
import type { ChartFilterScope } from "@cxado/gui/lib/dashboard/chart-filters"
import type { DashboardMatrixRow } from "@cxado/gui/lib/dashboard/serialize-dashboard"
import type { TableLabels } from "@cxado/gui/lib/ui/table-labels"
import { FSTEC_TABLE_LABELS } from "@cxado/gui/lib/ui/table-labels"
import { getDashboardDisplayStatusName } from "@cxado/gui/lib/statuses/workflow"

export type DashboardMatrixLinkTargets = {
  organization: (orgId: number) => string
  subdivision?: (orgId: number, subId: number) => string
  order: (orderId: number) => string
  measure: (row: DashboardMatrixRow) => string
}

export function DashboardMatrixTable({
  items,
  linkTargets,
  chartScope = "global",
  columnFilters,
  onColumnFiltersChange,
  pageSize = 50,
  labels = FSTEC_TABLE_LABELS,
}: {
  items: DashboardMatrixRow[]
  linkTargets: DashboardMatrixLinkTargets
  chartScope?: ChartFilterScope
  columnFilters?: ColumnFiltersState
  onColumnFiltersChange?: (filters: ColumnFiltersState) => void
  pageSize?: number
  labels?: TableLabels
}) {
  const columns = useMemo<ColumnDef<DashboardMatrixRow>[]>(() => {
    const base: ColumnDef<DashboardMatrixRow>[] = [
      createOrganizationColumn(
        (row) => row.order.organization,
        (org) => linkTargets.organization(org.id),
        "w-[14%]"
      ),
    ]

    if (chartScope === "global" || chartScope === "organization") {
      base.push(
        createSubdivisionColumn<DashboardMatrixRow>(
          (row) => row.subdivision ?? null,
          (sub, row) =>
            linkTargets.subdivision
              ? linkTargets.subdivision(row.order.organization.id, sub.id)
              : undefined
        )
      )
    }

    if (chartScope === "subdivision") {
      base.push(
        createOrderColumn(
          (row) => ({ id: row.orderId, title: row.order.title }),
          (order) => linkTargets.order(order.id),
          "w-[20%]",
          "orderTitle"
        )
      )
    } else {
      base.push(
        createOrderColumn(
          (row) => ({ id: row.orderId, title: row.order.title }),
          (order) => linkTargets.order(order.id),
          "w-[18%]"
        )
      )
    }

    base.push(
      createMeasureColumn(
        (row) => row.measure,
        () => "#",
        {
          width: "min-w-[10rem] w-[24%]",
          linkClassName: undefined,
          hrefFromRow: (row) => linkTargets.measure(row),
        }
      ),
      createMatrixWorkflowStatusColumn(
        (row) => getDashboardDisplayStatusName(row),
        (row) => row.isOverdue
      ),
      createDueAtColumn<DashboardMatrixRow>("dueAt")
    )

    return base
  }, [chartScope, linkTargets, labels])

  return (
    <DataTable
      columns={columns}
      data={items}
      pageSize={pageSize}
      columnFilters={columnFilters}
      onColumnFiltersChange={onColumnFiltersChange}
      hideOnMobileColumnIds={["organization", "order", "orderTitle", "subdivisionName"]}
      searchPlaceholder={`Поиск по ${labels.organization.toLowerCase()}, поручению, мере…`}
      globalFilterFn={(row, _columnId, filterValue) => {
        const q = String(filterValue).toLowerCase()
        if (!q) return true
        const haystack = [
          row.order.organization.name,
          row.subdivision?.name,
          row.order.title,
          row.measure.name,
          getDashboardDisplayStatusName(row),
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase()
        return haystack.includes(q)
      }}
      empty={
        <EmptyTableState title="Нет данных" description="Нет мер для отображения" />
      }
    />
  )
}
