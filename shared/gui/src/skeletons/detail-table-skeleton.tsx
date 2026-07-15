import { DataTableShell } from "@cxado/gui/layout/data-table-shell"
import { PageHeaderSkeleton } from "@cxado/gui/skeletons/page-header-skeleton"
import {
  PageContentShell,
  TableToolbarSkeleton,
} from "@cxado/gui/skeletons/primitives"
import { TableSkeleton } from "@cxado/gui/ui/table-skeleton"

export function DetailTableSkeleton({
  columns = 8,
  rows = 6,
}: {
  columns?: number
  rows?: number
}) {
  return (
    <PageContentShell>
      <PageHeaderSkeleton showBack showActions />
      <DataTableShell toolbar={<TableToolbarSkeleton />}>
        <TableSkeleton columns={columns} rows={rows} />
      </DataTableShell>
    </PageContentShell>
  )
}
