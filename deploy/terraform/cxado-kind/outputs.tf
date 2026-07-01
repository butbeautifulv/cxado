output "egregore_api_url" {
  value = "http://127.0.0.1:8080"
}

output "egregore_ui_url" {
  value = "http://127.0.0.1:3000"
}

output "grafana_url" {
  value = "http://127.0.0.1:3002"
}

output "prometheus_url" {
  value = "http://127.0.0.1:9091"
}

output "veil_api_url" {
  value = "http://127.0.0.1:8090"
}

output "veil_mcp_url" {
  value = "http://127.0.0.1:8091"
}

output "postgres_url" {
  value     = module.data_plane.postgres_url
  sensitive = true
}

output "redis_url" {
  value     = module.data_plane.redis_url
  sensitive = true
}

output "qdrant_url" {
  value = module.data_plane.qdrant_url
}

output "neo4j_uri" {
  value = module.data_plane.neo4j_uri
}
