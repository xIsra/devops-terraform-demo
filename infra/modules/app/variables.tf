variable "name" {
  description = "Service name (used for all resources)"
  type        = string
}

variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "image" {
  description = "Docker image (e.g., resume-agent:latest)"
  type        = string
}

variable "port" {
  description = "Container port"
  type        = number
}

variable "replicas" {
  description = "Number of replicas"
  type        = number
  default     = 2
}

variable "ingress_path" {
  description = "Ingress path (e.g., /api, /resume-api)"
  type        = string
}

variable "ingress_rewrite" {
  description = "Whether to rewrite path"
  type        = bool
  default     = true
}

variable "health_path" {
  description = "Health check endpoint"
  type        = string
  default     = "/health"
}

variable "env_vars" {
  description = "Environment variables (non-secret)"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret environment variables"
  type        = map(string)
  default     = {}
  # Note: sensitive removed to allow use in for_each
  # Values are still base64 encoded in kubernetes_secret resource
}

variable "resources" {
  description = "Resource requests/limits"
  type = object({
    cpu_request    = optional(string, "100m")
    memory_request = optional(string, "128Mi")
    cpu_limit      = optional(string, "500m")
    memory_limit   = optional(string, "512Mi")
  })
  default = {}
}

variable "ingress_host" {
  description = "Hostname for ingress rules"
  type        = string
  default     = "devops-demo.local"
}
