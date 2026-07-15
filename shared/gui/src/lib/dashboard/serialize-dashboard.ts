import type { ScopedDashboardStats } from "@cxado/gui/lib/dashboard/stats"

export type SerializedMatrixItem = {
  id: number
  orderId: number
  dueAt: string
  isOverdue: boolean
  measure: {
    id: number
    name: string
    code: string | null
    description: string | null
  }
  order: {
    title: string
    issuedAt: string
    organization: { id: number; name: string }
  }
  status: { id: number; name: string; isTerminal: boolean }
  subdivision?: { id: number; name: string } | null
}

export type DashboardMatrixRow = SerializedMatrixItem

export type SerializedDashboardDto = {
  stats: ScopedDashboardStats
  items: SerializedMatrixItem[]
}
