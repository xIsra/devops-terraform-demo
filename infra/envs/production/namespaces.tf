# -----------------------------------------------------------------------------
# Environment Namespace
# -----------------------------------------------------------------------------
module "namespace" {
  source = "../../modules/namespace"

  name = var.environment
  labels = {
    "environment" = var.environment
  }

  depends_on = [kind_cluster.this]
}
