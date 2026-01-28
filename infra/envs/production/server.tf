module "server" {
  source = "../../modules/server"

  namespace     = var.environment
  image_version = var.server_version
  replicas      = var.server_replicas
  database_url  = module.postgresql.connection_string

  depends_on = [
    module.namespace,
    null_resource.wait_for_ingress,
    module.server_migration,
    module.postgresql
  ]
}
