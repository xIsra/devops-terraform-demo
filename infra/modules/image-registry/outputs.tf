locals {
  # Use host.docker.internal for Kind clusters to access host registry
  # This works on Docker Desktop (macOS/Windows)
  cluster_registry_endpoint = replace(var.registry_endpoint, "localhost", "host.docker.internal")
}

output "registry_url" {
  description = "Docker registry URL (for use inside Kind cluster)"
  value       = local.cluster_registry_endpoint
}

output "resume_agent_repository_url" {
  description = "Repository URL for resume-agent (for use inside Kind cluster)"
  value       = "${local.cluster_registry_endpoint}/${var.repository_prefix}/resume-agent"
}

output "server_repository_url" {
  description = "Repository URL for server (for use inside Kind cluster)"
  value       = "${local.cluster_registry_endpoint}/${var.repository_prefix}/server"
}

output "server_migration_repository_url" {
  description = "Repository URL for server-migration (for use inside Kind cluster)"
  value       = "${local.cluster_registry_endpoint}/${var.repository_prefix}/server-migration"
}

output "web_repository_url" {
  description = "Repository URL for web (for use inside Kind cluster)"
  value       = "${local.cluster_registry_endpoint}/${var.repository_prefix}/web"
}

output "all_repositories" {
  description = "All repository URLs (for use inside Kind cluster)"
  value = {
    resume_agent     = "${local.cluster_registry_endpoint}/${var.repository_prefix}/resume-agent"
    server           = "${local.cluster_registry_endpoint}/${var.repository_prefix}/server"
    server_migration = "${local.cluster_registry_endpoint}/${var.repository_prefix}/server-migration"
    web              = "${local.cluster_registry_endpoint}/${var.repository_prefix}/web"
  }
}
