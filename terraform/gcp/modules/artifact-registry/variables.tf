variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "location" {
  description = "Artifact Registry location."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID."
  type        = string
}

variable "format" {
  description = "Artifact Registry repository format."
  type        = string
  default     = "DOCKER"
}

variable "description" {
  description = "Artifact Registry repository description."
  type        = string
  default     = null
}
