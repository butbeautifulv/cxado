import { DataTableShell } from "@cxado/gui/layout/data-table-shell"
import { TableToolbarSkeleton } from "@cxado/gui/skeletons/primitives"
import { TableSkeleton } from "@cxado/gui/ui/table-skeleton"

export function TableOnlySkeleton({
  columns = 5,
  rows = 10,
}: {
  columns?: number
  rows?: number
}) {
  return (
    <DataTableShell toolbar={<TableToolbarSkeleton />}>
      <TableSkeleton columns={columns} rows={rows} />
    </DataTableShell>
  )
}
