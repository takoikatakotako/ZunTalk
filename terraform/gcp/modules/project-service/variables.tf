variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "services" {
  description = "GCP service APIs to enable."
  type        = set(string)
}

variable "disable_on_destroy" {
  description = "Whether to disable the service API when the resource is destroyed."
  type        = bool
  default     = false
}
