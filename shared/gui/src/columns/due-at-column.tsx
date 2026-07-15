import type { ColumnDef } from "@tanstack/react-table"
import { DataTableColumnHeader } from "@cxado/gui/data-table"
import { colMeta } from "@cxado/gui/lib/data-table/column-meta"
import { dateSortFn } from "@cxado/gui/lib/data-table/sort-helpers"
import { FSTEC_TABLE_LABELS } from "@cxado/gui/lib/ui/table-labels"
import { format } from "date-fns"

export function createDueAtColumn<TRow>(
  accessorKey: keyof TRow & string,
  title = FSTEC_TABLE_LABELS.dueAt
): ColumnDef<TRow> {
  return {
    accessorKey,
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title={title} />
    ),
    sortingFn: dateSortFn,
    cell: ({ row }) =>
      format(new Date(String(row.original[accessorKey])), "dd.MM.yyyy"),
    meta: colMeta(title, { valueType: "date", cellClassName: "w-28" }),
  }
}
