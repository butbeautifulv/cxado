variable "namespace" { type = string }
variable "neo4j_uri" { type = string }
variable "image_tag" { type = string }
variable "nats_url" { type = string }

locals {
  chart_path = abspath("${path.module}/../../../../../projects/veil/deploy/helm/veil")
}

resource "helm_release" "veil" {
  name      = "veil"
  chart     = local.chart_path
  namespace = var.namespace

  values = [
    file("${path.module}/values-cxado-kind.yaml"),
    yamlencode({
      global = {
        imageTag   = var.image_tag
        neo4jUri   = var.neo4j_uri
        natsUrl    = var.nats_url
        veilApiUrl = "http://veil-api.${var.namespace}.svc:8090"
      }
    }),
  ]

  timeout = 600
}

output "api_service_name" { value = "veil-api" }
output "mcp_service_name" { value = "veil-mcp" }
output "api_service_host" { value = "veil-api.${var.namespace}.svc.cluster.local" }
output "mcp_service_host" { value = "veil-mcp.${var.namespace}.svc.cluster.local" }
output "mcp_service_port" { value = 8091 }

resource "kubernetes_service" "veil_api" {
  metadata {
    name      = "veil-api"
    namespace = var.namespace
  }
  spec {
    selector = { app = "veil-api" }
    port {
      port        = 8090
      target_port = 8090
    }
  }
}

resource "kubernetes_service" "veil_mcp" {
  metadata {
    name      = "veil-mcp"
    namespace = var.namespace
  }
  spec {
    selector = { app = "veil-mcp" }
    port {
      port        = 8091
      target_port = 8091
    }
  }
}
