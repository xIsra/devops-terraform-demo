module "web" {
  source = "../../modules/web"

  namespace     = var.environment
  image_version = var.web_version
  replicas      = var.web_replicas
  api_base_url  = "https://${var.ingress_host}/api"

  depends_on = [
    module.namespace,
    null_resource.wait_for_ingress
  ]
}
