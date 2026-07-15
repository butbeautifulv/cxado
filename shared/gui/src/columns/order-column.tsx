import type { ColumnDef } from "@tanstack/react-table"
import { DataTableColumnHeader } from "@cxado/gui/data-table"
import { facetedFilter } from "@cxado/gui/lib/data-table/faceted-column"
import { textColumnMeta } from "@cxado/gui/lib/data-table/column-meta"
import { TextCell } from "@cxado/gui/lib/data-table/text-cell"
import { FSTEC_TABLE_LABELS } from "@cxado/gui/lib/ui/table-labels"

export function createOrderColumn<TRow>(
  accessor: (row: TRow) => { id: number; title: string },
  href: (order: { id: number; title: string }) => string,
  width = "w-[16%]",
  columnId = "order",
  title = FSTEC_TABLE_LABELS.order
): ColumnDef<TRow> {
  return {
    id: columnId,
    accessorFn: (row) => accessor(row).title,
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title={title} />
    ),
    cell: ({ row }) => {
      const order = accessor(row.original)
      return <TextCell text={order.title} href={href(order)} />
    },
    enableColumnFilter: true,
    filterFn: facetedFilter,
    meta: textColumnMeta(title, width),
  }
}
