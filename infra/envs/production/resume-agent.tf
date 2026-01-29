module "resume_agent" {
  source = "../../modules/resume-agent"

  namespace      = var.environment
  image_version  = var.resume_agent_version
  replicas       = var.resume_agent_replicas
  openai_api_key = var.openai_api_key
  openai_model   = var.openai_model
  ingress_host   = var.ingress_host
  registry_url   = var.registry_url != "" ? var.registry_url : module.image_registry.resume_agent_repository_url

  depends_on = [
    module.namespace,
    module.image_registry
  ]
}
