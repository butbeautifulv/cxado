export type {
  CompliancePresentationConfig,
  ComplianceStatCardMeta,
  ComplianceStatusDistribution,
  ComplianceDashboardStats,
  ComplianceLinkTargets,
  ComplianceDashboardProps,
} from "./ComplianceDashboard"
export { ComplianceDashboard } from "./ComplianceDashboard"

// Dashboard UI primitives — reference copies; require app-specific lib/ adapters.
// FSTEC continues to import from @/components/dashboard until full wire-up.
export { DashboardStatCards } from "./dashboard-stat-cards"
export { OverdueFilterActions } from "./overdue-filter-actions"
