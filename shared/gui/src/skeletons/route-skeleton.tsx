import { DashboardPageSkeleton } from "@cxado/gui/skeletons/dashboard-page-skeleton"
import { DetailCardsSkeleton } from "@cxado/gui/skeletons/detail-cards-skeleton"
import { DetailTableSkeleton } from "@cxado/gui/skeletons/detail-table-skeleton"
import { FormPageSkeleton } from "@cxado/gui/skeletons/form-page-skeleton"
import { PublicDetailSkeleton } from "@cxado/gui/skeletons/public-detail-skeleton"
import { PublicTablePageSkeleton } from "@cxado/gui/skeletons/table-page-skeleton"
import { SettingsHubSkeleton } from "@cxado/gui/skeletons/settings-hub-skeleton"
import { TablePageSkeleton } from "@cxado/gui/skeletons/table-page-skeleton"

export type RouteSkeletonVariant =
  | "table"
  | "form"
  | "dashboard"
  | "detail-table"
  | "detail-cards"
  | "settings-hub"
  | "public-table"
  | "public-detail"

export type RouteSkeletonProps = {
  variant: RouteSkeletonVariant
  columns?: number
  rows?: number
  fields?: number
  singleCard?: boolean
  showReportLink?: boolean
}

export function RouteSkeleton({
  variant,
  columns,
  rows,
  fields,
  singleCard,
  showReportLink,
}: RouteSkeletonProps) {
  switch (variant) {
    case "table":
      return <TablePageSkeleton columns={columns} rows={rows} />
    case "form":
      return (
        <FormPageSkeleton fields={fields} singleCard={singleCard} />
      )
    case "dashboard":
      return <DashboardPageSkeleton showReportLink={showReportLink} />
    case "detail-table":
      return <DetailTableSkeleton columns={columns} rows={rows} />
    case "detail-cards":
      return <DetailCardsSkeleton />
    case "settings-hub":
      return <SettingsHubSkeleton />
    case "public-table":
      return <PublicTablePageSkeleton columns={columns} rows={rows} />
    case "public-detail":
      return <PublicDetailSkeleton />
    default:
      return <TablePageSkeleton />
  }
}
