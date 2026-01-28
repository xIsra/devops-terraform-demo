module "app" {
  source = "../app"

  name      = "server"
  namespace = var.namespace
  image     = "server:${var.image_version}"
  port      = 3000
  replicas  = var.replicas

  ingress_path = "/api"
  health_path  = "/health"

  secrets = {
    DATABASE_URL = var.database_url
  }

  env_vars = {
    NODE_ENV    = "production"
    CORS_ORIGIN = "http://localhost"
  }
}
