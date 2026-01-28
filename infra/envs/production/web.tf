module "web" {
  source = "../../modules/web"

  namespace     = var.environment
  image_version = var.web_version
  replicas      = var.web_replicas

  depends_on = [
    kubernetes_namespace.app,
    null_resource.wait_for_ingress
  ]
}
