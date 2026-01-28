variable "namespace" {
  description = "Namespace for PostgreSQL"
  type        = string
  default     = "database"
}

variable "storage_size" {
  description = "Storage size for PostgreSQL PVC"
  type        = string
  default     = "5Gi"
}

variable "credentials" {
  description = "Database credentials"
  type = object({
    username = string
    password = string
    database = string
  })
  sensitive = true
}

variable "replicas" {
  description = "Number of PostgreSQL replicas"
  type        = number
  default     = 1
}
