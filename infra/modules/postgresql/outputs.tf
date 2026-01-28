output "namespace" {
  description = "Namespace where PostgreSQL is deployed"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "service_name" {
  description = "PostgreSQL service name"
  value       = kubernetes_service.this.metadata[0].name
}

output "service_fqdn" {
  description = "PostgreSQL service FQDN"
  value       = "${kubernetes_service.this.metadata[0].name}.${kubernetes_namespace.this.metadata[0].name}.svc.cluster.local"
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.credentials.username}:${var.credentials.password}@${kubernetes_service.this.metadata[0].name}.${kubernetes_namespace.this.metadata[0].name}.svc.cluster.local:5432/${var.credentials.database}"
  sensitive   = true
}
