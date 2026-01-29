module "resume_agent" {
  source = "../../modules/resume-agent"

  namespace      = var.environment
  image_version  = var.resume_agent_version
  replicas       = var.resume_agent_replicas
  openai_api_key = var.openai_api_key
  openai_model   = var.openai_model
  ingress_host   = var.ingress_host

  depends_on = [
    module.namespace,
    null_resource.wait_for_ingress
  ]
}
