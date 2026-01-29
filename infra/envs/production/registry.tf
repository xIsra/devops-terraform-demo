# -----------------------------------------------------------------------------
# Docker Registry
# Local registry for container images
# -----------------------------------------------------------------------------

module "docker_registry" {
  source = "../../modules/docker-registry"

  storage_size = "10Gi"
}

output "registry_url" {
  description = "Registry URL for cluster-internal access"
  value       = module.docker_registry.registry_url
}

output "registry_host" {
  description = "Registry hostname for cluster-internal access"
  value       = module.docker_registry.registry_host
}

output "registry_nodeport" {
  description = "Registry NodePort for external access"
  value       = module.docker_registry.nodeport
}
