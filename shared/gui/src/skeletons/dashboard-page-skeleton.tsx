import { DataTableShell } from "@cxado/gui/layout/data-table-shell"
import { PageHeaderSkeleton } from "@cxado/gui/skeletons/page-header-skeleton"
import {
  ChartsGridSkeleton,
  PageContentShell,
  StatCardsGridSkeleton,
  TableToolbarSkeleton,
} from "@cxado/gui/skeletons/primitives"
import { Card, CardContent, CardHeader } from "@cxado/gui/ui/card"
import { Skeleton } from "@cxado/gui/ui/skeleton"
import { TableSkeleton } from "@cxado/gui/ui/table-skeleton"

export function DashboardPageSkeleton({ showReportLink = false }: { showReportLink?: boolean }) {
  return (
    <PageContentShell>
      {showReportLink && (
        <Card>
          <CardHeader>
            <Skeleton className="h-5 w-40 max-w-full" />
            <Skeleton className="h-4 w-64 max-w-full" />
          </CardHeader>
          <CardContent>
            <Skeleton className="h-9 w-36" />
          </CardContent>
        </Card>
      )}
      <PageHeaderSkeleton showActions />
      <StatCardsGridSkeleton />
      <ChartsGridSkeleton />
      <DataTableShell toolbar={<TableToolbarSkeleton />}>
        <TableSkeleton columns={5} rows={8} />
      </DataTableShell>
    </PageContentShell>
  )
}
