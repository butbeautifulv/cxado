"use client"

import { MoonIcon, SunIcon } from "lucide-react"
import { useTheme } from "@cxado/gui/theme/theme-provider"

import { Button } from "@cxado/gui/ui/button"
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@cxado/gui/ui/tooltip"

export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme()
  const isDark = resolvedTheme === "dark"
  const label = isDark ? "Светлая тема" : "Тёмная тема"

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          aria-label={label}
          onClick={() => setTheme(isDark ? "light" : "dark")}
        >
          {isDark ? <SunIcon /> : <MoonIcon />}
        </Button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  )
}
