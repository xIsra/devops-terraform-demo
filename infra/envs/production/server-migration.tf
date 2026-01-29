# Migration Job for Server
# Runs database migrations before server deployment
module "server_migration" {
  source = "../../modules/server-migration"

  namespace     = var.environment
  image_version = var.server_version
  database_url  = module.postgresql.connection_string
  registry_url  = var.registry_url != "" ? var.registry_url : module.image_registry.server_migration_repository_url

  depends_on = [
    module.namespace,
    module.postgresql,
    module.image_registry
  ]
}
