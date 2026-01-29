# -----------------------------------------------------------------------------
# Image Registry Module
# Creates Docker registry for container images
# Note: Docker registry should run separately (via docker-compose.registry.yml)
# -----------------------------------------------------------------------------

# Configure Docker provider
provider "docker" {
  host = "unix:///var/run/docker.sock"

  registry_auth {
    address = var.registry_endpoint
  }
}

# Note: Docker registry doesn't require creating repositories upfront
# Repositories are created automatically when images are pushed
# These null resources serve as placeholders for dependency tracking

resource "null_resource" "resume_agent_repository" {
  triggers = {
    repository = "${var.repository_prefix}/resume-agent"
    registry   = var.registry_endpoint
  }
}

resource "null_resource" "server_repository" {
  triggers = {
    repository = "${var.repository_prefix}/server"
    registry   = var.registry_endpoint
  }
}

resource "null_resource" "server_migration_repository" {
  triggers = {
    repository = "${var.repository_prefix}/server-migration"
    registry   = var.registry_endpoint
  }
}

resource "null_resource" "web_repository" {
  triggers = {
    repository = "${var.repository_prefix}/web"
    registry   = var.registry_endpoint
  }
}
