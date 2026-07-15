import { DataTableShell } from "@cxado/gui/layout/data-table-shell"
import { PageHeaderSkeleton } from "@cxado/gui/skeletons/page-header-skeleton"
import {
  PageContentShell,
  TableToolbarSkeleton,
} from "@cxado/gui/skeletons/primitives"
import { TableSkeleton } from "@cxado/gui/ui/table-skeleton"

export function TablePageSkeleton({
  columns = 5,
  rows = 10,
  showBack = false,
  showActions = false,
}: {
  columns?: number
  rows?: number
  showBack?: boolean
  showActions?: boolean
}) {
  return (
    <PageContentShell>
      <PageHeaderSkeleton showBack={showBack} showActions={showActions} />
      <DataTableShell toolbar={<TableToolbarSkeleton />}>
        <TableSkeleton columns={columns} rows={rows} />
      </DataTableShell>
    </PageContentShell>
  )
}

export function PublicTablePageSkeleton({
  columns = 5,
  rows = 8,
}: {
  columns?: number
  rows?: number
}) {
  return <TablePageSkeleton columns={columns} rows={rows} showBack />
}
