variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "image_version" {
  description = "Server image version/tag"
  type        = string
}

variable "replicas" {
  description = "Number of server replicas"
  type        = number
  default     = 2
}

variable "database_url" {
  description = "PostgreSQL database connection string"
  type        = string
  sensitive   = true
}

variable "cors_origin" {
  description = "CORS origin for the server API (e.g., https://devops-demo.local)"
  type        = string
  default     = "https://devops-demo.local"
}

variable "ingress_host" {
  description = "Hostname for ingress rules"
  type        = string
  default     = "devops-demo.local"
}
