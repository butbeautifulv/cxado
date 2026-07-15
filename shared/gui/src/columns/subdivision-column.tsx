import type { ColumnDef } from "@tanstack/react-table"
import { DataTableColumnHeader } from "@cxado/gui/data-table"
import { facetedFilter } from "@cxado/gui/lib/data-table/faceted-column"
import { colMeta } from "@cxado/gui/lib/data-table/column-meta"
import { TextCell } from "@cxado/gui/lib/data-table/text-cell"
import { FSTEC_TABLE_LABELS } from "@cxado/gui/lib/ui/table-labels"

export function createSubdivisionColumn<TRow>(
  accessor: (row: TRow) => { id: number; name: string } | null | undefined,
  href?: (sub: { id: number; name: string }, row: TRow) => string | undefined,
  width = "w-[14%]",
  columnId = "subdivisionName",
  title = FSTEC_TABLE_LABELS.subdivision
): ColumnDef<TRow> {
  return {
    id: columnId,
    accessorFn: (row) => accessor(row)?.name ?? "—",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title={title} />
    ),
    cell: ({ row }) => {
      const sub = accessor(row.original)
      const label = sub?.name ?? "—"
      const link = sub && href ? href(sub, row.original) : undefined
      return <TextCell text={label} href={link} />
    },
    enableColumnFilter: true,
    filterFn: facetedFilter,
    meta: colMeta(title, { cellClassName: `max-w-0 ${width}` }),
  }
}
