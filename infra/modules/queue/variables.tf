variable "name" {
  description = "Queue name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to queue resources"
  type        = map(string)
  default     = {}
}
