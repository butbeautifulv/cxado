variable "namespace" { type = string }
variable "postgres_password" { type = string }
variable "redis_password" { type = string }
variable "neo4j_password" { type = string }
variable "profile" { type = string }

resource "helm_release" "postgresql" {
  name       = "cxado-postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "16.2.1"
  namespace  = var.namespace

  set {
    name  = "auth.postgresPassword"
    value = var.postgres_password
  }
  set {
    name  = "auth.database"
    value = "egregore"
  }
  set {
    name  = "primary.persistence.size"
    value = "2Gi"
  }
}

resource "helm_release" "redis" {
  name       = "cxado-redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = "20.6.2"
  namespace  = var.namespace

  set {
    name  = "auth.password"
    value = var.redis_password
  }
  set {
    name  = "architecture"
    value = "standalone"
  }
  set {
    name  = "master.persistence.size"
    value = "1Gi"
  }
}

resource "helm_release" "qdrant" {
  name       = "cxado-qdrant"
  repository = "https://qdrant.github.io/qdrant-helm"
  chart      = "qdrant"
  version    = "1.13.2"
  namespace  = var.namespace

  set {
    name  = "persistence.size"
    value = "2Gi"
  }
}

resource "kubernetes_stateful_set" "neo4j" {
  metadata {
    name      = "neo4j"
    namespace = var.namespace
    labels    = { app = "neo4j" }
  }
  spec {
    service_name = "neo4j"
    replicas     = 1
    selector { match_labels = { app = "neo4j" } }
    template {
      metadata { labels = { app = "neo4j" } }
      spec {
        # Avoid Kubernetes service env var injection (NEO4J_PORT_7687_TCP_PORT etc.)
        # which Neo4j can misinterpret as config settings (PORT.7687.TCP.PORT).
        enable_service_links = false
        container {
          name  = "neo4j"
          image = "neo4j:5"
          port { container_port = 7687 }
          port { container_port = 7474 }
          env {
            name  = "NEO4J_AUTH"
            value = "neo4j/${var.neo4j_password}"
          }
          env {
            name  = "NEO4J_PLUGINS"
            value = "[\"apoc\"]"
          }
          resources {
            limits = {
              memory = var.profile == "lite" ? "1Gi" : "2Gi"
            }
          }
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }
      }
    }
    volume_claim_template {
      metadata { name = "data" }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = { storage = "2Gi" }
        }
      }
    }
  }
}

resource "kubernetes_service" "neo4j" {
  metadata {
    name      = "neo4j"
    namespace = var.namespace
  }
  spec {
    selector = { app = "neo4j" }
    port {
      name        = "bolt"
      port        = 7687
      target_port = 7687
    }
    port {
      name        = "http"
      port        = 7474
      target_port = 7474
    }
  }
}

locals {
  postgres_host = "cxado-postgresql.${var.namespace}.svc.cluster.local"
  redis_host    = "cxado-redis-master.${var.namespace}.svc.cluster.local"
  qdrant_host   = "cxado-qdrant.${var.namespace}.svc.cluster.local"
}

output "postgres_host" { value = local.postgres_host }
output "postgres_port" { value = 5432 }
output "postgres_url" {
  value     = "postgresql://postgres:${var.postgres_password}@${local.postgres_host}:5432/egregore"
  sensitive = true
}
output "redis_host" { value = local.redis_host }
output "redis_port" { value = 6379 }
output "redis_url" {
  value     = "redis://:${var.redis_password}@${local.redis_host}:6379/0"
  sensitive = true
}
output "qdrant_url" { value = "http://${local.qdrant_host}:6333" }
output "neo4j_uri" { value = "neo4j://neo4j.${var.namespace}.svc.cluster.local:7687" }
