module "app" {
  source = "../app"

  name      = "server"
  namespace = var.namespace
  image     = "server:${var.image_version}"
  port      = 3000
  replicas  = var.replicas

  ingress_path    = "/api"
  ingress_rewrite = false # Use Prefix matching (more specific than /) instead of regex
  ingress_host    = var.ingress_host
  health_path     = "/health"

  secrets = {
    DATABASE_URL = var.database_url
  }

  env_vars = {
    NODE_ENV    = "production"
    CORS_ORIGIN = var.cors_origin
  }
}
