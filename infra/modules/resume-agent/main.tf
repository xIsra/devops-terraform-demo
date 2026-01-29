module "app" {
  source = "../app"

  name      = "resume-agent"
  namespace = var.namespace
  image     = var.registry_url != "" ? "${var.registry_url}/resume-agent:${var.image_version}" : "resume-agent:${var.image_version}"
  port      = 8000
  replicas  = var.replicas

  ingress_path = "/resume-api"
  ingress_host = var.ingress_host
  health_path  = "/api/v1/health"

  secrets = {
    OPENAI_API_KEY = var.openai_api_key
  }

  env_vars = {
    OPENAI_MODEL = var.openai_model
    CORS_ORIGINS = "*"
  }

  resources = {
    cpu_request    = "100m"
    memory_request = "256Mi"
    cpu_limit      = "500m"
    memory_limit   = "512Mi"
  }
}
