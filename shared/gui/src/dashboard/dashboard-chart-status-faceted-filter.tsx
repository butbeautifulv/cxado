"use client"

import { CheckIcon, ListFilterIcon } from "lucide-react"
import { Badge } from "@cxado/gui/ui/badge"
import { Button } from "@cxado/gui/ui/button"
import { Checkbox } from "@cxado/gui/ui/checkbox"
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@cxado/gui/ui/command"
import { Popover, PopoverContent, PopoverTrigger } from "@cxado/gui/ui/popover"
import { Separator } from "@cxado/gui/ui/separator"
import { OverflowText } from "@cxado/gui/layout/overflow-text"
import {
  canHideChartCategory,
  hiddenChartStatusCount,
  isChartStatusVisible,
  setVisibleChartStatuses,
} from "@cxado/gui/lib/dashboard/chart-visibility"
import type { StatusDistribution } from "@cxado/gui/lib/dashboard/stats"
import type { DashboardPresentationConfig } from "@cxado/gui/lib/dashboard/presentation-config"
import { cn } from "@cxado/gui/utils"

export function DashboardChartStatusFacetedFilter({
  statusDistribution,
  presentation,
  visibleChartStatuses,
  onVisibleChartStatusesChange,
}: {
  statusDistribution: StatusDistribution[]
  presentation: DashboardPresentationConfig
  visibleChartStatuses: ReadonlySet<string>
  onVisibleChartStatusesChange: (next: Set<string>) => void
}) {
  const { statusOrder, pieColors } = presentation
  const countByStatus = Object.fromEntries(
    statusDistribution.map((row) => [row.status, row.count])
  )
  const fillByStatus = Object.fromEntries(
    statusDistribution.map((row) => [row.status, row.fill])
  )

  const options = statusOrder.map((status, index) => ({
    value: status,
    label: status,
    count: countByStatus[status] ?? 0,
    color: fillByStatus[status] ?? pieColors[index % pieColors.length],
  }))

  const hiddenCount = hiddenChartStatusCount(visibleChartStatuses, statusOrder)

  function toggleStatus(status: string) {
    const next = new Set(visibleChartStatuses)
    if (next.has(status)) {
      if (!canHideChartCategory(next)) return
      next.delete(status)
    } else {
      next.add(status)
    }
    onVisibleChartStatusesChange(setVisibleChartStatuses(next, statusOrder))
  }

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="outline" size="sm" className="relative h-8 gap-2">
          <ListFilterIcon className="size-3.5" />
          Статусы на графиках
          {hiddenCount > 0 && (
            <Badge
              variant="secondary"
              className="pointer-events-none rounded-full px-1.5 text-[10px]"
            >
              −{hiddenCount}
            </Badge>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-80 p-0 sm:w-96" align="end">
        <Command>
          <CommandInput placeholder="Статусы на графиках" />
          <CommandList>
            <CommandEmpty>Нет статусов</CommandEmpty>
            <CommandGroup>
              {options.map((option) => {
                const isSelected = isChartStatusVisible(
                  visibleChartStatuses,
                  option.value
                )
                const isLastVisible =
                  isSelected && !canHideChartCategory(visibleChartStatuses)
                return (
                  <CommandItem
                    key={option.value}
                    disabled={isLastVisible}
                    onSelect={() => {
                      if (!isLastVisible) toggleStatus(option.value)
                    }}
                    className={cn(isLastVisible && "opacity-60")}
                  >
                    <Checkbox
                      checked={isSelected}
                      disabled={isLastVisible}
                      className="pointer-events-none"
                    />
                    <span
                      className="mt-0.5 h-2 w-2 shrink-0 rounded-[2px]"
                      style={{ backgroundColor: option.color }}
                    />
                    <OverflowText className="min-w-0 flex-1">
                      {option.label}
                    </OverflowText>
                    <span className="text-muted-foreground tabular-nums">
                      {option.count}
                    </span>
                    <CheckIcon
                      className={cn("size-4", isSelected ? "opacity-100" : "opacity-0")}
                    />
                  </CommandItem>
                )
              })}
            </CommandGroup>
          </CommandList>
          <Separator />
          <div className="flex items-center gap-2 p-2">
            <Button
              variant="ghost"
              size="sm"
              className="h-8 flex-1"
              onClick={() =>
                onVisibleChartStatusesChange(
                  setVisibleChartStatuses(
                    new Set(statusOrder),
                    statusOrder
                  )
                )
              }
            >
              Выбрать все
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="h-8 flex-1"
              onClick={() =>
                onVisibleChartStatusesChange(
                  setVisibleChartStatuses(
                    new Set(statusOrder),
                    statusOrder
                  )
                )
              }
            >
              Сбросить
            </Button>
          </div>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
