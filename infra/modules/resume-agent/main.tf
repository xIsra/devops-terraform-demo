module "app" {
  source = "../app"

  name      = "resume-agent"
  namespace = var.namespace
  image     = "resume-agent:${var.image_version}"
  port      = 8000
  replicas  = var.replicas

  ingress_path = "/resume-api"
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
