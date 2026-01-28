# -----------------------------------------------------------------------------
# Main Configuration
# Orchestrates infrastructure and service deployments
# -----------------------------------------------------------------------------

# Environment-specific local values
locals {
  environment = var.environment

  # Common labels for all resources in this environment
  common_labels = {
    "environment"                  = var.environment
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = "devops-demo"
  }

  # Resource naming prefix
  name_prefix = "${var.cluster_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# Kind Cluster
# Creates a local Kubernetes cluster using Kind (Kubernetes in Docker)
# This is the foundation for all other resources
# -----------------------------------------------------------------------------

resource "kind_cluster" "this" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role  = "control-plane"
      image = "kindest/node:${var.kubernetes_version}"

      # Configure port mappings for ingress controller
      # This allows accessing services via localhost:80 and localhost:443
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }
      # Grafana NodePort mapping
      extra_port_mappings {
        container_port = 30080
        host_port      = 30080
        protocol       = "TCP"
      }

      # Required labels for ingress-nginx to work with Kind
      kubeadm_config_patches = [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
        EOT
      ]
    }

    # Add worker nodes for better pod distribution
    node {
      role  = "worker"
      image = "kindest/node:${var.kubernetes_version}"
    }

    node {
      role  = "worker"
      image = "kindest/node:${var.kubernetes_version}"
    }
  }
}

# -----------------------------------------------------------------------------
# File Organization
# -----------------------------------------------------------------------------
# Infrastructure components are organized in separate files:
# - namespaces.tf (Environment namespace)
# - ingress.tf (Nginx ingress controller)
# - database.tf (PostgreSQL)
# - observability.tf (Prometheus, Grafana, Loki, OTEL)
#
# Services are defined in:
# - resume-agent.tf
# - server.tf
# - server-migration.tf
# - web.tf
