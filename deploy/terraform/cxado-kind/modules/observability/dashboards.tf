variable "namespace_obs" { type = string }

resource "kubernetes_config_map" "cxado_overview_dashboard" {
  metadata {
    name      = "cxado-overview-dashboard"
    namespace = var.namespace_obs
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "cxado-overview.json" = file("${path.module}/../../../../observability/grafana/dashboards/cxado/cxado-overview.json")
  }
}
