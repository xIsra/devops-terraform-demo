output "deployment_name" {
  description = "Name of the deployment"
  value       = kubernetes_deployment.this.metadata[0].name
}

output "service_name" {
  description = "Name of the service"
  value       = kubernetes_service.this.metadata[0].name
}

output "ingress_name" {
  description = "Name of the ingress"
  value       = kubernetes_ingress_v1.this.metadata[0].name
}

output "namespace" {
  description = "Namespace where resources are deployed"
  value       = var.namespace
}
