variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider (manually created)"
  type        = string
}
