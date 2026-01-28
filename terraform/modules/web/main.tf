module "app" {
  source = "../app"

  name      = "web"
  namespace = var.namespace
  image     = "web:${var.version}"
  port      = 3000
  replicas  = var.replicas

  ingress_path    = "/"
  ingress_rewrite = false # No rewrite for root path
  health_path     = "/"

  env_vars = {
    NODE_ENV = "production"
  }
}
