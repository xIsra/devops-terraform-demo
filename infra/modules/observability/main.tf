# Namespace
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Prometheus + Grafana Stack
resource "helm_release" "kube_prometheus" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.this.metadata[0].name
  version    = "55.0.0"

  values = [
    <<-EOT
    grafana:
      adminPassword: ${var.grafana_admin_password}
      service:
        type: NodePort
        nodePort: ${var.grafana_node_port}
      persistence:
        enabled: true
        size: 10Gi
      grafana.ini:
        server:
          # Configure for direct NodePort access (no subpath)
          domain: "localhost"
    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        retention: 30d
        storageSpec:
          volumeClaimTemplate:
            spec:
              accessModes: ["ReadWriteOnce"]
              resources:
                requests:
                  storage: 20Gi
    EOT
  ]

  depends_on = [kubernetes_namespace.this]
}

# Grafana Ingress - Removed to avoid redirect loops
# Access Grafana directly via NodePort: http://localhost:30080 (admin/admin)
# The ingress was causing ERR_TOO_MANY_REDIRECTS due to subpath configuration conflicts

# Loki Stack
resource "helm_release" "loki" {
  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.this.metadata[0].name
  version    = "2.10.0"

  values = [
    <<-EOT
    promtail:
      enabled: true
      config:
        clients:
          - url: http://loki-stack:3100/loki/api/v1/push
    grafana:
      enabled: false
    loki:
      persistence:
        enabled: true
        size: 10Gi
    EOT
  ]

  depends_on = [kubernetes_namespace.this]
}

# OpenTelemetry Collector
resource "helm_release" "opentelemetry" {
  name       = "opentelemetry-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.this.metadata[0].name
  version    = "0.80.0"

  values = [
    <<-EOT
    mode: deployment
    replicaCount: 1
    config:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318
      exporters:
        prometheus:
          endpoint: "0.0.0.0:8889"
        loki:
          endpoint: "http://loki-stack:3100/loki/api/v1/push"
      service:
        pipelines:
          metrics:
            receivers: [otlp]
            exporters: [prometheus]
          logs:
            receivers: [otlp]
            exporters: [loki]
          traces:
            receivers: [otlp]
            exporters: [logging]
    EOT
  ]

  depends_on = [kubernetes_namespace.this]
}
