variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "image_version" {
  description = "Web image version/tag"
  type        = string
}

variable "replicas" {
  description = "Number of web replicas"
  type        = number
  default     = 2
}

variable "api_base_url" {
  description = "API base URL for the web application (e.g., http://localhost/api)"
  type        = string
  default     = "http://localhost/api"
}
