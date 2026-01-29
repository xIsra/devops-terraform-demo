# -----------------------------------------------------------------------------
# Docker Registry Module
# Deploys a local Docker registry for container images
# -----------------------------------------------------------------------------

locals {
  labels = {
    "app"                          = "docker-registry"
    "app.kubernetes.io/name"       = "docker-registry"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

# Namespace for registry
resource "kubernetes_namespace" "this" {
  metadata {
    name   = "docker-registry"
    labels = local.labels
  }
}

# Persistent volume for registry storage
resource "kubernetes_persistent_volume_claim" "this" {
  metadata {
    name      = "registry-storage"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

# Registry Deployment
resource "kubernetes_deployment" "this" {
  metadata {
    name      = "docker-registry"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app" = "docker-registry"
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "registry"
          image = "registry:2"

          port {
            container_port = 5000
            protocol       = "TCP"
          }

          env {
            name  = "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY"
            value = "/var/lib/registry"
          }

          volume_mount {
            name       = "registry-storage"
            mount_path = "/var/lib/registry"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/v2/"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/v2/"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "registry-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.this.metadata[0].name
          }
        }
      }
    }
  }
}

# Registry Service
resource "kubernetes_service" "this" {
  metadata {
    name      = "docker-registry"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      "app" = "docker-registry"
    }

    port {
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# NodePort service for external access (for CI/CD)
resource "kubernetes_service" "nodeport" {
  metadata {
    name      = "docker-registry-nodeport"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      "app" = "docker-registry"
    }

    port {
      port        = 5000
      target_port = 5000
      node_port   = 30500
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}
