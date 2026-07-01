variable "namespace" { type = string }
variable "neo4j_uri" { type = string }
variable "image_tag" { type = string }

resource "kubernetes_job" "graph_bootstrap" {
  metadata {
    name      = "veil-graph-bootstrap"
    namespace = var.namespace
  }

  spec {
    backoff_limit = 3
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"
        container {
          name  = "graph-bootstrap"
          image = "veil-api:${var.image_tag}"
          image_pull_policy = "IfNotPresent"
          env {
            name  = "NEO4J_URI"
            value = var.neo4j_uri
          }
          env {
            name  = "GRAPH_PACK_SKIP"
            value = "0"
          }
          command = ["/bin/sh", "-c", "echo graph-bootstrap placeholder — seed via compose or veil CLI"]
        }
      }
    }
  }

  wait_for_completion = false
}
