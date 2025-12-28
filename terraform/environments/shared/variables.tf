variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider (manually created)"
  type        = string
}

variable "ecr_allowed_account_ids" {
  description = "List of AWS account IDs allowed to access the ECR repository"
  type        = list(string)
}
