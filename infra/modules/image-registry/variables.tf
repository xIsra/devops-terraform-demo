variable "registry_endpoint" {
  description = "Docker registry endpoint (host:port)"
  type        = string
  default     = "localhost:5555"
}

variable "repository_prefix" {
  description = "Prefix for repository names"
  type        = string
  default     = "devops-demo"
}
