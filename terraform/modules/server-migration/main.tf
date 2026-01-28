# Secret for migration job
resource "kubernetes_secret" "this" {
  metadata {
    name      = "server-migration-secrets"
    namespace = var.namespace
    labels = {
      "app"                          = "server-migration"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    DATABASE_URL = base64encode(var.database_url)
  }
  type = "Opaque"
}

# Migration Job for Server
# Runs database migrations before server deployment
resource "kubernetes_job" "this" {
  metadata {
    name      = "server-migration-${replace(var.version, ".", "-")}"
    namespace = var.namespace
    labels = {
      "app"                          = "server-migration"
      "app.kubernetes.io/name"       = "server-migration"
      "app.kubernetes.io/managed-by" = "terraform"
      "version"                      = var.version
    }
  }

  spec {
    # Prevent multiple migrations from running simultaneously
    completions                = 1
    parallelism                = 1
    backoff_limit              = 3
    ttl_seconds_after_finished = 3600 # Clean up after 1 hour

    template {
      metadata {
        labels = {
          "app"     = "server-migration"
          "version" = var.version
        }
      }

      spec {
        restart_policy = "Never"

        # Wait for database to be ready before running migration
        init_container {
          name              = "wait-for-db"
          image             = "postgres:16-alpine"
          image_pull_policy = "IfNotPresent"
          command = [
            "sh",
            "-c",
            <<-EOT
              until pg_isready -h postgresql.database.svc.cluster.local -p 5432; do
                echo "Waiting for database to be ready..."
                sleep 2
              done
              echo "Database is ready!"
            EOT
          ]
        }

        container {
          name              = "migration"
          image             = "server-migration:${var.version}"
          image_pull_policy = "Never" # Use Never for local Kind images

          # The migration image should have an entrypoint that runs: pnpm --filter @typescript/db db:push
          # Or: cd packages/db && pnpm db:push
          command = ["sh", "-c", "cd /app/packages/db && pnpm db:push"]

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.this.metadata[0].name
                key  = "DATABASE_URL"
              }
            }
          }

          env {
            name  = "NODE_ENV"
            value = "production"
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
        }
      }
    }
  }

  lifecycle {
    # Jobs are immutable - if they exist and completed, don't recreate them
    ignore_changes = [
      spec[0].template[0].spec[0].container[0].image,
      spec[0].template[0].spec[0].container[0].command,
    ]
  }
}
