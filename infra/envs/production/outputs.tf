# -----------------------------------------------------------------------------
# Cluster Outputs
# -----------------------------------------------------------------------------
output "cluster_name" {
  description = "Name of the Kind cluster"
  value       = kind_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = kind_cluster.this.endpoint
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = kind_cluster.this.kubeconfig_path
}

# -----------------------------------------------------------------------------
# Service Outputs
# -----------------------------------------------------------------------------
output "services" {
  description = "Deployed services and their endpoints"
  value = {
    resume_agent = {
      service   = module.resume_agent.service_name
      namespace = module.resume_agent.namespace
      endpoint  = "https://${var.ingress_host}/resume-api"
    }
    server = {
      service   = module.server.service_name
      namespace = module.server.namespace
      endpoint  = "https://${var.ingress_host}/api"
    }
    web = {
      service   = module.web.service_name
      namespace = module.web.namespace
      endpoint  = "https://${var.ingress_host}/"
    }
  }
}

output "usage_instructions" {
  description = "Instructions for accessing the applications"
  value       = <<-EOT
    
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                     Applications Deployed Successfully                 ║
    ╚═══════════════════════════════════════════════════════════════════════╝
    
    Access your applications at:
    • Web: https://${var.ingress_host}/
    • Server API: https://${var.ingress_host}/api
    • Resume Agent: https://${var.ingress_host}/resume-api
    
    Make sure to add ${var.ingress_host} to /etc/hosts:
    $ echo "127.0.0.1 ${var.ingress_host}" | sudo tee -a /etc/hosts
    
    Observability:
    • Grafana: http://localhost:30080 (admin/admin)
    
    To check cluster status:
    $ kubectl get pods -n ${var.environment}
    $ kubectl get ingress -n ${var.environment}
    
  EOT
}
