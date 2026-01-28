output "namespace" {
  description = "Namespace where observability stack is deployed"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://localhost:${var.grafana_node_port}"
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = "kube-prometheus-stack-prometheus"
}

output "loki_service" {
  description = "Loki service name"
  value       = "loki-stack"
}
