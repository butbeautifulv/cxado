import type { ColumnDef } from "@tanstack/react-table"
import { DataTableColumnHeader } from "@cxado/gui/data-table"
import { colMeta } from "@cxado/gui/lib/data-table/column-meta"
import { FSTEC_TABLE_LABELS } from "@cxado/gui/lib/ui/table-labels"

export function createCodeColumn<TRow>(
  accessor: (row: TRow) => string | null,
  opts?: { title?: string; cellClassName?: string; mono?: boolean }
): ColumnDef<TRow> {
  const title = opts?.title ?? FSTEC_TABLE_LABELS.code
  const cellClassName = opts?.cellClassName ?? "w-24"
  const mono = opts?.mono ?? true

  return {
    id: "code",
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title={title} />
    ),
    accessorFn: (row) => accessor(row) ?? "—",
    cell: ({ row }) => {
      const value = accessor(row.original) ?? "—"
      return mono ? (
        <span className="font-mono text-muted-foreground">{value}</span>
      ) : (
        <span>{value}</span>
      )
    },
    enableColumnFilter: false,
    meta: colMeta(title, { faceted: false, cellClassName }),
  }
}
