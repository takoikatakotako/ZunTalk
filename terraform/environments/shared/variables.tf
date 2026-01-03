# =============================================================================
# General Variables
# =============================================================================

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# =============================================================================
# Cross-Account Access Variables
# =============================================================================

variable "development_account_id" {
  description = "AWS account ID for development environment"
  type        = string
}

variable "production_account_id" {
  description = "AWS account ID for production environment"
  type        = string
}

# =============================================================================
# GitHub Actions Variables
# =============================================================================

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider (manually created)"
  type        = string
}
