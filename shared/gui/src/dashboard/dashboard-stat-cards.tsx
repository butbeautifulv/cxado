"use client"

import { Badge } from "@cxado/gui/ui/badge"
import {
  Card,
  CardAction,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@cxado/gui/ui/card"
import type { ScopedDashboardStats } from "@cxado/gui/lib/dashboard/stats"
import type { DashboardPresentationConfig } from "@cxado/gui/lib/dashboard/presentation-config"
import { MotionStagger, MotionStaggerItem } from "@cxado/gui/motion"
import { cn } from "@cxado/gui/utils"

function countForStatus(
  distribution: ScopedDashboardStats["statusDistribution"],
  status: string
) {
  return distribution.find((row) => row.status === status)?.count ?? 0
}

export function DashboardStatCards({
  stats,
  presentation,
  activeStatus,
  onStatusClick,
}: {
  stats: ScopedDashboardStats
  presentation: DashboardPresentationConfig
  activeStatus?: string
  onStatusClick?: (status: string) => void
}) {
  const { statusOrder, statCardMeta } = presentation
  const total = stats.statusDistribution.reduce((sum, row) => sum + row.count, 0)

  const cards = statusOrder.map((status) => {
    const value = countForStatus(stats.statusDistribution, status)
    const meta = statCardMeta[status]
    const Icon = meta.icon
    const badge = meta.badge?.(value, total) ?? null

    return { status, value, hint: meta.hint, Icon, badge, badgeVariant: meta.badgeVariant }
  })

  return (
    <MotionStagger className="grid grid-cols-1 gap-4 @2xl/main:grid-cols-2 @4xl/main:grid-cols-3">
      {cards.map((card) => {
        const interactive = Boolean(onStatusClick)
        const isActive = interactive && activeStatus === card.status

        const cardBody = (
          <>
            <CardHeader>
              <CardDescription>{card.status}</CardDescription>
              <CardTitle className="text-2xl font-semibold tabular-nums @[250px]/card:text-3xl">
                {card.value}
              </CardTitle>
              {card.badge && (
                <CardAction>
                  <Badge variant={card.badgeVariant ?? "outline"}>{card.badge}</Badge>
                </CardAction>
              )}
            </CardHeader>
            <CardFooter className="flex-col items-start gap-1.5 text-sm">
              <div className="flex gap-2 font-medium">
                <card.Icon className="size-4 text-muted-foreground" />
                {card.hint}
              </div>
            </CardFooter>
          </>
        )

        return (
          <MotionStaggerItem key={card.status}>
            <Card
              className={cn(
                "@container/card shadow-xs transition-colors",
                interactive && "hover:ring-2 hover:ring-ring/40",
                isActive && "ring-2 ring-primary"
              )}
            >
              {interactive ? (
                <button
                  type="button"
                  className="w-full text-left"
                  aria-pressed={isActive}
                  onClick={() => onStatusClick?.(card.status)}
                >
                  {cardBody}
                </button>
              ) : (
                cardBody
              )}
            </Card>
          </MotionStaggerItem>
        )
      })}
    </MotionStagger>
  )
}
