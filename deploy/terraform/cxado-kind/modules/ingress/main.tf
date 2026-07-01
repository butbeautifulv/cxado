variable "namespace_app" { type = string }
variable "namespace_veil" { type = string }
variable "namespace_obs" { type = string }
variable "egregore_api_service" { type = string }
variable "egregore_ui_service" { type = string }
variable "veil_api_service" { type = string }
variable "veil_mcp_service" { type = string }
variable "grafana_service" { type = string }
variable "prometheus_service" { type = string }

resource "kubernetes_ingress_v1" "cxado" {
  metadata {
    name      = "cxado-ingress"
    namespace = var.namespace_app
    annotations = {
      "nginx.ingress.kubernetes.io/use-regex" = "true"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.egregore_api_service
              port { number = 8080 }
            }
          }
        }
        path {
          path      = "/ui"
          path_type = "Prefix"
          backend {
            service {
              name = var.egregore_ui_service
              port { number = 3000 }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "veil" {
  metadata {
    name      = "veil-ingress"
    namespace = var.namespace_veil
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.veil_api_service
              port { number = 8090 }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "obs" {
  metadata {
    name      = "obs-ingress"
    namespace = var.namespace_obs
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.grafana_service
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
