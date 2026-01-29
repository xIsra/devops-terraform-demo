module "web" {
  source = "../../modules/web"

  namespace     = var.environment
  image_version = var.web_version
  replicas      = var.web_replicas
  api_base_url  = "https://${var.ingress_host}/api"
  ingress_host  = var.ingress_host

  depends_on = [
    module.namespace
    # Note: Server dependency removed for faster startup. Ingress will route once ready.
  ]
}
