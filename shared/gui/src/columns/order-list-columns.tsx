import type { ColumnDef } from "@tanstack/react-table"
import { DataTableColumnHeader, DataTableRowLink } from "@cxado/gui/data-table"
import { actionsColumnMeta, colMeta, textColumnMeta } from "@cxado/gui/lib/data-table/column-meta"
import { dateSortFn } from "@cxado/gui/lib/data-table/sort-helpers"
import { TextCell } from "@cxado/gui/lib/data-table/text-cell"
import { FSTEC_TABLE_LABELS, type TableLabels } from "@cxado/gui/lib/ui/table-labels"
import { format } from "date-fns"

export type OrderListRow = {
  id: number
  title: string
  issuedAt: string
  itemCount: number
}

export function createOrderListColumns(
  orderHref: (row: OrderListRow) => string,
  labels: Pick<TableLabels, "order" | "issuedAt" | "itemCount"> = FSTEC_TABLE_LABELS
): ColumnDef<OrderListRow>[] {
  return [
    {
      accessorKey: "title",
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title={labels.order} />
      ),
      cell: ({ row }) => (
        <TextCell text={row.original.title} href={orderHref(row.original)} />
      ),
      meta: textColumnMeta(labels.order, "w-[50%]"),
    },
    {
      accessorKey: "issuedAt",
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title={labels.issuedAt} />
      ),
      sortingFn: dateSortFn,
      cell: ({ row }) => format(new Date(row.original.issuedAt), "dd.MM.yyyy"),
      meta: colMeta(labels.issuedAt, { valueType: "date", cellClassName: "w-28" }),
    },
    {
      id: "items",
      accessorFn: (row) => row.itemCount,
      header: ({ column }) => (
        <DataTableColumnHeader column={column} title={labels.itemCount} />
      ),
      cell: ({ row }) => row.original.itemCount,
      meta: colMeta(labels.itemCount, { cellClassName: "w-20" }),
    },
    {
      id: "actions",
      header: "",
      enableSorting: false,
      enableHiding: false,
      enableColumnFilter: false,
      cell: ({ row }) => <DataTableRowLink href={orderHref(row.original)} />,
      meta: actionsColumnMeta(),
    },
  ]
}
