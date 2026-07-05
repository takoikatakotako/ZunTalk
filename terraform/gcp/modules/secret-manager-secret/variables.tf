variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "secret_id" {
  description = "Secret Manager secret ID."
  type        = string
}

variable "replication_location" {
  description = "Secret Manager user-managed replication location."
  type        = string
}

variable "accessor_members" {
  description = "IAM members granted roles/secretmanager.secretAccessor."
  type        = set(string)
  default     = []
}
