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
  default     = 1
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

variable "registry_url" {
  description = "Docker registry URL (e.g., localhost:5000 or docker-registry.docker-registry.svc.cluster.local:5000)"
  type        = string
  default     = ""
}
