# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------
variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "devops-demo"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the Kind cluster"
  type        = string
  default     = "v1.29.2"
}

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["production", "staging", "testing"], var.environment)
    error_message = "Environment must be production, staging, or testing."
  }
}

# -----------------------------------------------------------------------------
# Service Versions
# -----------------------------------------------------------------------------
variable "resume_agent_version" {
  description = "Resume agent image version/tag"
  type        = string
  default     = "latest"
}

variable "server_version" {
  description = "Server image version/tag"
  type        = string
  default     = "latest"
}

variable "web_version" {
  description = "Web image version/tag"
  type        = string
  default     = "latest"
}

# -----------------------------------------------------------------------------
# Service Replicas
# -----------------------------------------------------------------------------
variable "resume_agent_replicas" {
  description = "Number of resume-agent replicas"
  type        = number
  default     = 1
}

variable "server_replicas" {
  description = "Number of server replicas"
  type        = number
  default     = 1
}

variable "web_replicas" {
  description = "Number of web replicas"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------------
variable "openai_api_key" {
  description = "OpenAI API key for resume-agent"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_model" {
  description = "OpenAI model to use"
  type        = string
  default     = "gpt-4o-mini"
}

variable "database_url" {
  description = "PostgreSQL database URL"
  type        = string
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------
variable "db_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "postgres"
}

variable "db_storage_size" {
  description = "PostgreSQL storage size"
  type        = string
  default     = "5Gi"
}

# -----------------------------------------------------------------------------
# Ingress Configuration
# -----------------------------------------------------------------------------
variable "ingress_host" {
  description = "Hostname for ingress (e.g., devops-demo.local for local development with SSL)"
  type        = string
  default     = "devops-demo.local"
}

# -----------------------------------------------------------------------------
# Docker Registry Configuration
# -----------------------------------------------------------------------------
variable "registry_endpoint" {
  description = "Docker registry endpoint (host:port)"
  type        = string
  default     = "localhost:5555"
}

variable "registry_url" {
  description = "Docker registry URL for container images (default: localhost:5555)"
  type        = string
  default     = "" # Will be set to module output if not provided
}
