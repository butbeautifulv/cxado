import type {
  TrackedItemRow,
  TrackedItemStatus,
} from "@cxado/gui/lib/ui/tracked-item-types"

export type PublicStatus = TrackedItemStatus

export type PublicItem = TrackedItemRow & {
  orderId: number
  orderTitle: string
  orderIssuedAt: string
}
