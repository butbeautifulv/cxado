variable "postgres_password" { type = string }
variable "redis_password" { type = string }
variable "neo4j_password" { type = string }
variable "enable_langfuse" { type = bool }

locals {
  namespaces = {
    data = "cxado-data"
    app  = "cxado-app"
    veil = "veil"
    obs  = "cxado-obs"
  }
}

resource "kubernetes_namespace" "cxado_data" {
  metadata { name = local.namespaces.data }
}

resource "kubernetes_namespace" "cxado_app" {
  metadata { name = local.namespaces.app }
}

resource "kubernetes_namespace" "veil" {
  metadata { name = local.namespaces.veil }
}

resource "kubernetes_namespace" "cxado_obs" {
  metadata { name = local.namespaces.obs }
}

resource "kubernetes_namespace" "cxado_langfuse" {
  count = var.enable_langfuse ? 1 : 0
  metadata { name = "cxado-langfuse" }
}

resource "kubernetes_secret" "cxado_credentials" {
  metadata {
    name      = "cxado-credentials"
    namespace = local.namespaces.data
  }
  type = "Opaque"
  data = {
    postgres-password = base64encode(var.postgres_password)
    redis-password    = base64encode(var.redis_password)
    neo4j-password    = base64encode(var.neo4j_password)
  }
}

output "namespace_data" { value = local.namespaces.data }
output "namespace_app" { value = local.namespaces.app }
output "namespace_veil" { value = local.namespaces.veil }
output "namespace_obs" { value = local.namespaces.obs }
