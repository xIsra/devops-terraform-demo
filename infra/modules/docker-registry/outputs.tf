output "namespace" {
  description = "Namespace where registry is deployed"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "service_name" {
  description = "Registry service name"
  value       = kubernetes_service.this.metadata[0].name
}

output "registry_url" {
  description = "Registry URL for cluster-internal access"
  value       = "${kubernetes_service.this.metadata[0].name}.${kubernetes_namespace.this.metadata[0].name}.svc.cluster.local:5000"
}

output "registry_host" {
  description = "Registry hostname for cluster-internal access"
  value       = "${kubernetes_service.this.metadata[0].name}.${kubernetes_namespace.this.metadata[0].name}.svc.cluster.local"
}

output "nodeport" {
  description = "NodePort for external access"
  value       = kubernetes_service.nodeport.spec[0].port[0].node_port
}
