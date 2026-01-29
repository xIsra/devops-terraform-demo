variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "image_version" {
  description = "Server migration image version/tag"
  type        = string
}

variable "database_url" {
  description = "PostgreSQL database connection string"
  type        = string
  sensitive   = true
}

variable "registry_url" {
  description = "Docker registry URL (e.g., localhost:5000 or docker-registry.docker-registry.svc.cluster.local:5000)"
  type        = string
  default     = ""
}
