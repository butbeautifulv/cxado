export type OrderItemStatusLike = {
  status: { name: string; isTerminal?: boolean }
  dueAt: Date | string
}

export function isOrderItemOverdue(
  item: OrderItemStatusLike,
  now: Date = new Date()
): boolean {
  const terminal = item.status.isTerminal ?? false
  return !terminal && new Date(item.dueAt) < now
}

export function getDisplayStatusName(
  item: OrderItemStatusLike,
  now: Date = new Date()
): string {
  return isOrderItemOverdue(item, now) ? "Просрочено" : item.status.name
}

export const getDashboardDisplayStatusName = getDisplayStatusName

