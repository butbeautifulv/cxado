export type ChartFilterScope = "global" | "organization" | "subdivision"

export type StatusDistribution = {
  status: string
  count: number
  fill: string
}

export type StatusBreakdownRow = { label: string } & Record<string, number>

