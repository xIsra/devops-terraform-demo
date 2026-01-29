variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "image_version" {
  description = "Resume agent image version/tag"
  type        = string
}

variable "replicas" {
  description = "Number of resume-agent replicas"
  type        = number
  default     = 1
}

variable "openai_api_key" {
  description = "OpenAI API key for resume-agent"
  type        = string
  sensitive   = true
}

variable "openai_model" {
  description = "OpenAI model to use"
  type        = string
  default     = "gpt-4o-mini"
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
