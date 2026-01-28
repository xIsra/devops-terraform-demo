variable "namespace" {
  description = "Namespace for observability stack"
  type        = string
  default     = "monitoring"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "grafana_node_port" {
  description = "NodePort for Grafana service"
  type        = number
  default     = 30080
}
