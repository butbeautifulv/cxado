# Optional network policies — app may reach data plane; observability may scrape app/veil.
resource "kubernetes_network_policy" "data_ingress_from_app" {
  metadata {
    name      = "allow-from-cxado-app"
    namespace = local.namespaces.data
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "cxado-app"
          }
        }
      }
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "veil"
          }
        }
      }
    }
  }
}
