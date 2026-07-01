variable "namespace" { type = string }
variable "image_tag" { type = string }
variable "worker_replicas" { type = number }

variable "postgres_host" { type = string }
variable "postgres_port" { type = number }
variable "postgres_user" { type = string }
variable "postgres_password" { type = string }
variable "postgres_db" { type = string }

variable "redis_host" { type = string }
variable "redis_port" { type = number }
variable "redis_password" { type = string }

variable "qdrant_url" { type = string }
variable "veil_mcp_url" { type = string }
variable "otel_endpoint" { type = string }
variable "langfuse_host" {
  type    = string
  default = ""
}

locals {
  chart_path = abspath("${path.module}/../../../../../projects/egregore/deploy/helm/egregore")
}

resource "helm_release" "egregore" {
  name      = "egregore"
  chart     = local.chart_path
  namespace = var.namespace

  values = [
    yamlencode({
      image = {
        repository = "cxado/egregore"
        tag        = var.image_tag
      }
      ui = {
        image = {
          repository = "cxado/egregore-ui"
          tag        = var.image_tag
        }
      }
      worker = {
        replicas = var.worker_replicas
      }
      postgres = {
        host     = var.postgres_host
        port     = var.postgres_port
        user     = var.postgres_user
        password = var.postgres_password
        database = var.postgres_db
      }
      redis = {
        host     = var.redis_host
        port     = var.redis_port
        password = var.redis_password
      }
      qdrant = {
        url = var.qdrant_url
      }
      veil = {
        mcpUrl = var.veil_mcp_url
      }
      otel = {
        endpoint = var.otel_endpoint
      }
      langfuse = {
        host = var.langfuse_host
      }
    }),
  ]

  timeout = 600
}

output "api_service_name" { value = "egregore-api" }
output "ui_service_name" { value = "egregore-ui" }
