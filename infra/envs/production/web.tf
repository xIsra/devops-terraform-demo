module "web" {
  source = "../../modules/web"

  namespace     = var.environment
  image_version = var.web_version
  replicas      = var.web_replicas
  api_base_url  = "https://${var.ingress_host}/api"
  ingress_host  = var.ingress_host
  registry_url  = var.registry_url != "" ? var.registry_url : module.docker_registry.registry_url

  depends_on = [
    module.namespace,
    module.docker_registry
    # Note: Server dependency removed for faster startup. Ingress will route once ready.
  ]
}
