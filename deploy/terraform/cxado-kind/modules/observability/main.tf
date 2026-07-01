variable "namespace_obs" { type = string }
variable "namespace_app" { type = string }
variable "namespace_veil" { type = string }

resource "helm_release" "kube_prometheus" {
  name       = "cxado-kube-prom"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "67.5.0"
  namespace  = var.namespace_obs

  values = [file("${path.module}/values-prometheus.yaml")]

  timeout = 900
}

resource "helm_release" "tempo" {
  name       = "cxado-tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.16.0"
  namespace  = var.namespace_obs

  set {
    name  = "tempo.receivers.otlp.protocols.grpc.endpoint"
    value = "0.0.0.0:4317"
  }

  timeout = 600
}

output "grafana_service_name" { value = "cxado-kube-prom-grafana" }
output "prometheus_service_name" { value = "cxado-kube-prom-kube-prometheus" }
output "otlp_endpoint" { value = "http://cxado-tempo.${var.namespace_obs}.svc.cluster.local:4317" }
