# -----------------------------------------------------------------------------
# Image Registry
# Creates Docker registry for container images
# Note: Docker registry must be running separately (see README)
# -----------------------------------------------------------------------------

module "image_registry" {
  source = "../../modules/image-registry"

  registry_endpoint = var.registry_endpoint
  repository_prefix = "${var.cluster_name}-${var.environment}"
}

output "registry_url" {
  description = "Docker registry URL (for host access, e.g., localhost:5555)"
  value       = var.registry_endpoint
}

output "cluster_registry_url" {
  description = "Docker registry URL (for cluster access, e.g., host.docker.internal:5555)"
  value       = module.image_registry.registry_url
}

output "registry_repositories" {
  description = "All repository URLs"
  value       = module.image_registry.all_repositories
}
