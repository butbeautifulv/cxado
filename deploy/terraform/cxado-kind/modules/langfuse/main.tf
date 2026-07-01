variable "enable_langfuse" { type = bool }
variable "namespace" { type = string }

resource "kubernetes_config_map" "langfuse_notice" {
  count = var.enable_langfuse ? 1 : 0

  metadata {
    name      = "langfuse-stack-notice"
    namespace = var.namespace
  }

  data = {
    README = "Langfuse Helm chart placeholder. For dev use compose: make -C projects/egregore langfuse-dev-setup"
    URL    = "http://langfuse-web.${var.namespace}.svc.cluster.local:3000"
  }
}

output "langfuse_host" {
  value = var.enable_langfuse ? "http://langfuse-web.${var.namespace}.svc.cluster.local:3000" : ""
}
