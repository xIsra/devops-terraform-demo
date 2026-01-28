# Migration Job for Server
# Runs database migrations before server deployment
module "server_migration" {
  source = "../../modules/server-migration"

  namespace    = var.environment
  version      = var.server_version
  database_url = module.postgresql.connection_string

  depends_on = [
    kubernetes_namespace.app,
    module.postgresql
  ]
}
