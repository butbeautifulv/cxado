locals {
  worker_replicas = var.profile == "lite" ? 1 : var.worker_replicas
}

module "platform" {
  source = "./modules/platform"

  postgres_password = var.postgres_password
  redis_password    = var.redis_password
  neo4j_password    = var.neo4j_password
  enable_langfuse   = var.enable_langfuse
}

module "data_plane" {
  source = "./modules/data-plane"

  namespace         = module.platform.namespace_data
  postgres_password = var.postgres_password
  redis_password    = var.redis_password
  neo4j_password    = var.neo4j_password
  profile           = var.profile

  depends_on = [module.platform]
}

module "observability" {
  source = "./modules/observability"

  namespace_obs = module.platform.namespace_obs
  namespace_app = module.platform.namespace_app
  namespace_veil = module.platform.namespace_veil

  depends_on = [module.platform]
}

module "veil_graph" {
  source = "./modules/veil-graph"

  namespace     = module.platform.namespace_veil
  neo4j_uri     = module.data_plane.neo4j_uri
  image_tag     = var.veil_image_tag
  nats_url      = ""

  depends_on = [module.data_plane]
}

module "egregore" {
  source = "./modules/egregore"

  namespace      = module.platform.namespace_app
  image_tag      = var.egregore_image_tag
  worker_replicas = local.worker_replicas

  postgres_host     = module.data_plane.postgres_host
  postgres_port     = module.data_plane.postgres_port
  postgres_user     = "postgres"
  postgres_password = var.postgres_password
  postgres_db       = "egregore"
  redis_host        = module.data_plane.redis_host
  redis_port        = module.data_plane.redis_port
  redis_password    = var.redis_password
  qdrant_url        = module.data_plane.qdrant_url
  veil_mcp_url      = "http://${module.veil_graph.mcp_service_host}:${module.veil_graph.mcp_service_port}/mcp"
  otel_endpoint     = module.observability.otlp_endpoint
  langfuse_host     = var.enable_langfuse ? module.langfuse[0].langfuse_host : ""

  depends_on = [module.data_plane, module.veil_graph, module.observability]
}

module "langfuse" {
  count  = var.enable_langfuse ? 1 : 0
  source = "./modules/langfuse"

  enable_langfuse = var.enable_langfuse
  namespace       = "cxado-langfuse"

  depends_on = [module.platform]
}

module "ingress" {
  source = "./modules/ingress"

  namespace_app  = module.platform.namespace_app
  namespace_veil = module.platform.namespace_veil
  namespace_obs  = module.platform.namespace_obs

  egregore_api_service = module.egregore.api_service_name
  egregore_ui_service  = module.egregore.ui_service_name
  veil_api_service     = module.veil_graph.api_service_name
  veil_mcp_service     = module.veil_graph.mcp_service_name
  grafana_service      = module.observability.grafana_service_name
  prometheus_service   = module.observability.prometheus_service_name

  depends_on = [module.egregore, module.veil_graph, module.observability]
}
