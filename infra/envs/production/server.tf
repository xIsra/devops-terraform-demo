module "server" {
  source = "../../modules/server"

  namespace     = var.environment
  image_version = var.server_version
  replicas      = var.server_replicas
  database_url  = module.postgresql.connection_string
  cors_origin   = "https://${var.ingress_host}"
  ingress_host  = var.ingress_host
  registry_url  = var.registry_url != "" ? var.registry_url : module.image_registry.server_repository_url

  depends_on = [
    module.namespace,
    module.server_migration,
    module.postgresql,
    module.image_registry
  ]
}
