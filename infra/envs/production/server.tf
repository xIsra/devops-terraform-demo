module "server" {
  source = "../../modules/server"

  namespace     = var.environment
  image_version = var.server_version
  replicas      = var.server_replicas
  database_url  = module.postgresql.connection_string
  cors_origin   = "https://${var.ingress_host}"
  ingress_host  = var.ingress_host

  depends_on = [
    module.namespace,
    module.server_migration,
    module.postgresql
  ]
}
