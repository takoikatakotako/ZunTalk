variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
}

variable "location" {
  description = "Cloud Run location."
  type        = string
}

variable "service_account_email" {
  description = "Runtime service account email."
  type        = string
}

variable "image" {
  description = "Container image."
  type        = string
}

variable "container_port" {
  description = "Container port."
  type        = number
  default     = 8080
}

variable "min_instance_count" {
  description = "Minimum number of Cloud Run instances."
  type        = number
  default     = 0
}

variable "environment_variables" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Secret-backed environment variables."
  type = map(object({
    secret_id = string
    version   = string
  }))
  default = {}
}

variable "invoker_members" {
  description = "IAM members granted roles/run.invoker."
  type        = set(string)
  default     = []
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled."
  type        = bool
  default     = false
}
