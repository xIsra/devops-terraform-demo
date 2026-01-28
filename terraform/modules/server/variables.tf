variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "version" {
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
