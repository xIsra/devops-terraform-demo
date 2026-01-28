variable "name" {
  description = "Namespace name"
  type        = string
}

variable "labels" {
  description = "Additional labels for the namespace"
  type        = map(string)
  default     = {}
}
