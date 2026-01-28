variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "version" {
  description = "Server migration image version/tag"
  type        = string
}

variable "database_url" {
  description = "PostgreSQL database connection string"
  type        = string
  sensitive   = true
}
