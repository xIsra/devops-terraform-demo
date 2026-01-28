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
