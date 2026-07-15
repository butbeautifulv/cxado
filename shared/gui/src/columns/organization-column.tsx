import type { ColumnDef } from "@tanstack/react-table"
import { DataTableColumnHeader } from "@cxado/gui/data-table"
import { facetedFilter } from "@cxado/gui/lib/data-table/faceted-column"
import { textColumnMeta } from "@cxado/gui/lib/data-table/column-meta"
import { TextCell } from "@cxado/gui/lib/data-table/text-cell"
import { FSTEC_TABLE_LABELS } from "@cxado/gui/lib/ui/table-labels"

export function createOrganizationColumn<TRow>(
  accessor: (row: TRow) => { id: number; name: string },
  href: (org: { id: number; name: string }) => string,
  width = "w-[12%]",
  title = FSTEC_TABLE_LABELS.organization
): ColumnDef<TRow> {
  return {
    id: "organization",
    accessorFn: (row) => accessor(row).name,
    header: ({ column }) => (
      <DataTableColumnHeader column={column} title={title} />
    ),
    cell: ({ row }) => {
      const org = accessor(row.original)
      return (
        <TextCell text={org.name} href={href(org)} linkClassName="font-normal" />
      )
    },
    enableColumnFilter: true,
    filterFn: facetedFilter,
    meta: textColumnMeta(title, width),
  }
}
