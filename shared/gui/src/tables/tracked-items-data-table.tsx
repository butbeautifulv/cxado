"use client"

import { useMemo } from "react"
import type { ColumnDef, ColumnFiltersState } from "@tanstack/react-table"
import {
  DataTable,
  DataTableRowLink,
} from "@cxado/gui/data-table"
import { actionsColumnMeta } from "@cxado/gui/lib/data-table/column-meta"
import {
  createCodeColumn,
  createDueAtColumn,
  createMeasureColumn,
  createOrderColumn,
  createWorkflowStatusColumn,
} from "@cxado/gui/columns"
import { createSubdivisionColumn } from "@cxado/gui/columns/subdivision-column"
import {
  getDisplayStatusName as defaultGetDisplayStatusName,
  isOrderItemOverdue as defaultIsOrderItemOverdue,
} from "@cxado/gui/lib/statuses/workflow"
import {
  FSTEC_TABLE_LABELS,
  type TableLabels,
} from "@cxado/gui/lib/ui/table-labels"
import type {
  TrackedItemRow,
  TrackedItemStatus,
  TrackedItemsColumnPreset,
} from "@cxado/gui/lib/ui/tracked-item-types"
import type { OrderItemStatusLike } from "@cxado/gui/lib/statuses/workflow"

export type { TrackedItemRow, TrackedItemStatus, TrackedItemsColumnPreset }

type TrackedRow = TrackedItemRow & {
  isOverdue: boolean
  displayStatus: string
}

export function TrackedItemsDataTable({
  basePath,
  items,
  statuses,
  preset = {},
  labels = FSTEC_TABLE_LABELS,
  getDisplayStatusName,
  isOverdue,
  columnFilters,
  onColumnFiltersChange,
  pageSize = 50,
}: {
  basePath: string
  items: TrackedItemRow[]
  statuses: TrackedItemStatus[]
  preset?: TrackedItemsColumnPreset
  labels?: Pick<
    TableLabels,
    "searchWithOrder" | "searchWithoutOrder" | "measuresNotFound"
  >
  getDisplayStatusName?: (item: OrderItemStatusLike, now?: Date) => string
  isOverdue?: (item: OrderItemStatusLike, now?: Date) => boolean
  columnFilters?: ColumnFiltersState
  onColumnFiltersChange?: (filters: ColumnFiltersState) => void
  pageSize?: number
}) {
  const {
    showSubdivisionColumn = false,
    showOrderColumn = false,
    subdivisionHref,
    actionLabel,
  } = preset

  const statusById = useMemo(
    () => new Map(statuses.map((s) => [s.id, s])),
    [statuses]
  )

  const rows: TrackedRow[] = useMemo(() => {
    const now = new Date()
    return items.map((item) => {
      const meta = statusById.get(item.status.id)
      const statusWithTerminal = {
        name: item.status.name,
        isTerminal: meta?.isTerminal ?? item.status.isTerminal ?? false,
      }
      const rowItem = { ...item, status: statusWithTerminal, dueAt: item.dueAt }
      return {
        ...item,
        isOverdue: (isOverdue ?? defaultIsOrderItemOverdue)(rowItem, now),
        displayStatus: (getDisplayStatusName ?? defaultGetDisplayStatusName)(
          rowItem,
          now
        ),
      }
    })
  }, [items, statusById, getDisplayStatusName, isOverdue])

  const columns = useMemo<ColumnDef<TrackedRow>[]>(() => {
    const base: ColumnDef<TrackedRow>[] = []

    if (showOrderColumn && items.some((item) => item.orderTitle)) {
      base.push(
        createOrderColumn(
          (row) => ({ id: row.orderId ?? 0, title: row.orderTitle ?? "—" }),
          (order) => `${basePath}/orders/${order.id}`,
          "w-[18%]"
        )
      )
    }

    if (showSubdivisionColumn) {
      base.push(
        createSubdivisionColumn(
          (row) =>
            row.subdivisionId != null && row.subdivisionName
              ? { id: row.subdivisionId, name: row.subdivisionName }
              : null,
          (sub) => (subdivisionHref ? subdivisionHref(sub.id) : undefined),
          "w-[16%]"
        )
      )
    }

    base.push(
      createMeasureColumn(
        (row) => ({ id: row.id, name: row.measure.name }),
        () => "#",
        {
          width: "min-w-[10rem] w-[28%]",
          linkClassName: undefined,
          hrefFromRow: (row) => `${basePath}/items/${row.id}`,
        }
      ),
      createCodeColumn((row) => row.measure.code),
      createDueAtColumn<TrackedRow>("dueAt"),
      createWorkflowStatusColumn(),
      {
        id: "actions",
        header: "",
        enableSorting: false,
        enableHiding: false,
        enableColumnFilter: false,
        cell: ({ row }) => (
          <DataTableRowLink
            href={`${basePath}/items/${row.original.id}`}
            label={actionLabel}
          />
        ),
        meta: actionsColumnMeta(),
      }
    )

    return base
  }, [basePath, showSubdivisionColumn, showOrderColumn, subdivisionHref, actionLabel, items])

  const hideOnMobileColumnIds = useMemo(() => {
    const ids: string[] = []
    if (showSubdivisionColumn) ids.push("subdivisionName")
    if (showOrderColumn) ids.push("orderTitle")
    return ids.length > 0 ? ids : undefined
  }, [showSubdivisionColumn, showOrderColumn])

  return (
    <DataTable
      columns={columns}
      data={rows}
      pageSize={pageSize}
      columnFilters={columnFilters}
      onColumnFiltersChange={onColumnFiltersChange}
      hideOnMobileColumnIds={hideOnMobileColumnIds}
      searchPlaceholder={
        showOrderColumn ? labels.searchWithOrder : labels.searchWithoutOrder
      }
      globalFilterFn={(row, _columnId, filterValue) => {
        const q = String(filterValue).toLowerCase()
        if (!q) return true
        return [
          row.measure.name,
          row.measure.code ?? "",
          row.orderTitle ?? "",
          row.subdivisionName ?? "",
        ]
          .join(" ")
          .toLowerCase()
          .includes(q)
      }}
      empty={
        <p className="py-8 text-center text-sm text-muted-foreground">
          {labels.measuresNotFound}
        </p>
      }
    />
  )
}
