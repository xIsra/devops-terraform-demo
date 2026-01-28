output "deployment_name" {
  description = "Name of the deployment"
  value       = module.app.deployment_name
}

output "service_name" {
  description = "Name of the service"
  value       = module.app.service_name
}

output "ingress_name" {
  description = "Name of the ingress"
  value       = module.app.ingress_name
}

output "namespace" {
  description = "Namespace where resources are deployed"
  value       = module.app.namespace
}
