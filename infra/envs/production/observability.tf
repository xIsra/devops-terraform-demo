# -----------------------------------------------------------------------------
# Observability Stack
# -----------------------------------------------------------------------------
module "observability" {
  source = "../../modules/observability"

  namespace              = "monitoring"
  grafana_admin_password = "admin" # Override in production via tfvars
  grafana_node_port      = 30080

  depends_on = [kind_cluster.this]
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = module.observability.grafana_url
}
