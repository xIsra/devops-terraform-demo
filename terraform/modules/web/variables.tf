variable "namespace" {
  description = "Target namespace"
  type        = string
}

variable "version" {
  description = "Web image version/tag"
  type        = string
}

variable "replicas" {
  description = "Number of web replicas"
  type        = number
  default     = 2
}
