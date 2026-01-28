resource "kubernetes_namespace" "this" {
  metadata {
    name = var.name
    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform"
    }, var.labels)
  }
}
