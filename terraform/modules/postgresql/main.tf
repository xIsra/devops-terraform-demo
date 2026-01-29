locals {
  labels = {
    "app"                          = "postgresql"
    "app.kubernetes.io/name"       = "postgresql"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

# Namespace
resource "kubernetes_namespace" "this" {
  metadata {
    name   = var.namespace
    labels = local.labels
  }
}

# Secret for credentials
resource "kubernetes_secret" "credentials" {
  metadata {
    name      = "postgresql-credentials"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  data = {
    username = base64encode(var.credentials.username)
    password = base64encode(var.credentials.password)
    database = base64encode(var.credentials.database)
  }

  type = "Opaque"
}

# ConfigMap for PostgreSQL config
resource "kubernetes_config_map" "config" {
  metadata {
    name      = "postgresql-config"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  data = {
    "postgresql.conf" = <<-EOT
      max_connections = 100
      shared_buffers = 256MB
      effective_cache_size = 1GB
      maintenance_work_mem = 64MB
      checkpoint_completion_target = 0.9
      wal_buffers = 16MB
      default_statistics_target = 100
      random_page_cost = 1.1
      effective_io_concurrency = 200
      work_mem = 4MB
      min_wal_size = 1GB
      max_wal_size = 4GB
    EOT
  }
}

# Note: PersistentVolumeClaim is created automatically by StatefulSet volume_claim_template
# No need for separate PVC resource

# StatefulSet
resource "kubernetes_stateful_set" "this" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    service_name = "postgresql"
    replicas     = var.replicas

    selector {
      match_labels = {
        "app" = "postgresql"
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "postgresql"
          image = "postgres:16-alpine"

          port {
            container_port = 5432
            name           = "postgresql"
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.credentials.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.credentials.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.credentials.metadata[0].name
                key  = "database"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/postgresql"
            read_only  = true
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", var.credentials.username]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", var.credentials.username]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }

        volume {
          name = "config"
          config_map {
            name         = kubernetes_config_map.config.metadata[0].name
            default_mode = "0644"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name   = "data"
        labels = local.labels
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "standard"
        resources {
          requests = {
            storage = var.storage_size
          }
        }
      }
    }
  }
}

# Service
resource "kubernetes_service" "this" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    selector = {
      "app" = "postgresql"
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
      name        = "postgresql"
    }

    type = "ClusterIP"
  }
}
