variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "version" {
  description = "Resume agent image version/tag"
  type        = string
}

variable "replicas" {
  description = "Number of resume-agent replicas"
  type        = number
  default     = 2
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
