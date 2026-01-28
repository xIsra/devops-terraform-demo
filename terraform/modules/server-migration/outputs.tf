output "job_name" {
  description = "Name of the migration job"
  value       = kubernetes_job.this.metadata[0].name
}

output "secret_name" {
  description = "Name of the migration secret"
  value       = kubernetes_secret.this.metadata[0].name
}

output "namespace" {
  description = "Namespace where resources are deployed"
  value       = var.namespace
}
