locals {
  labels = {
    "app"                          = var.name
    "app.kubernetes.io/name"       = var.name
    "app.kubernetes.io/managed-by" = "terraform"
  }

  # Convert maps to sets of keys for for_each (workaround for sensitive map limitation)
  secrets_keys  = toset(keys(var.secrets))
  env_vars_keys = toset(keys(var.env_vars))
}

# Secret (only if secrets provided)
resource "kubernetes_secret" "this" {
  count = length(var.secrets) > 0 ? 1 : 0

  metadata {
    name      = "${var.name}-secrets"
    namespace = var.namespace
    labels    = local.labels
  }

  # Use data (base64 encoded) for secrets
  data = { for k, v in var.secrets : k => base64encode(v) }
  type = "Opaque"
}

# ConfigMap (only if env_vars provided)
resource "kubernetes_config_map" "this" {
  count = length(var.env_vars) > 0 ? 1 : 0

  metadata {
    name      = "${var.name}-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = var.env_vars
}

# Deployment
resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        "app" = var.name
      }
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name              = var.name
          image             = var.image
          image_pull_policy = "Never" # Use Never for local Kind images

          port {
            container_port = var.port
            protocol       = "TCP"
          }

          # Env from ConfigMap (only if ConfigMap exists and has values)
          dynamic "env" {
            for_each = local.env_vars_keys
            content {
              name = env.value
              value_from {
                config_map_key_ref {
                  name = kubernetes_config_map.this[0].metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          # Env from Secret (only if Secret exists and has values)
          dynamic "env" {
            for_each = local.secrets_keys
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.this[0].metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          resources {
            requests = {
              cpu    = var.resources.cpu_request
              memory = var.resources.memory_request
            }
            limits = {
              cpu    = var.resources.cpu_limit
              memory = var.resources.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = var.health_path
              port = var.port
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }

          readiness_probe {
            http_get {
              path = var.health_path
              port = var.port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
            success_threshold     = 1
          }
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Service
resource "kubernetes_service" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = {
      "app" = var.name
    }

    port {
      port        = 80
      target_port = var.port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Ingress
resource "kubernetes_ingress_v1" "this" {
  metadata {
    name      = "${var.name}-ingress"
    namespace = var.namespace
    labels    = local.labels

    annotations = var.ingress_rewrite ? {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
    } : {}
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "localhost"

      http {
        path {
          path      = var.ingress_rewrite ? "${var.ingress_path}(/|$)(.*)" : var.ingress_path
          path_type = var.ingress_rewrite ? "ImplementationSpecific" : "Prefix"

          backend {
            service {
              name = kubernetes_service.this.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.this]
}
