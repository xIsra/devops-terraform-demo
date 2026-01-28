# -----------------------------------------------------------------------------
# Environment Namespace
# -----------------------------------------------------------------------------
module "namespace" {
  source = "../../modules/namespace"

  name = var.environment
  labels = {
    "environment" = var.environment
  }
}

# Alias for backward compatibility
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.environment
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes if namespace already exists
      metadata[0].labels,
    ]
  }

  depends_on = [kind_cluster.this]
}
