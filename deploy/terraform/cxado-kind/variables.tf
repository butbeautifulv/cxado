variable "kubeconfig_path" {
  type        = string
  description = "Path to kubeconfig for kind cluster"
  default     = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "kubectl context (kind-cxado)"
  default     = "kind-cxado"
}

variable "profile" {
  type        = string
  description = "cxado profile: default or lite"
  default     = "default"
}

variable "enable_langfuse" {
  type        = bool
  description = "Deploy optional Langfuse stack"
  default     = false
}

variable "egregore_image_tag" {
  type    = string
  default = "local"
}

variable "veil_image_tag" {
  type    = string
  default = "local"
}

variable "postgres_password" {
  type      = string
  sensitive = true
  default   = "password"
}

variable "redis_password" {
  type      = string
  sensitive = true
  default   = "password"
}

variable "neo4j_password" {
  type      = string
  sensitive = true
  default   = "neo4jpassword"
}

variable "worker_replicas" {
  type    = number
  default = 2
}
