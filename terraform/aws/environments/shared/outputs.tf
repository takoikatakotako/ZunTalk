# =============================================================================
# ECR Outputs - Backend
# =============================================================================

output "ecr_backend_repository_url" {
  description = "The URL of the backend ECR repository"
  value       = module.ecr_backend.repository_url
}

output "ecr_backend_repository_name" {
  description = "The name of the backend ECR repository"
  value       = module.ecr_backend.repository_name
}

output "ecr_backend_registry_id" {
  description = "The registry ID where the backend repository was created"
  value       = module.ecr_backend.registry_id
}

# =============================================================================
# ECR Outputs - Slack Notifier
# =============================================================================

output "ecr_slack_notifier_repository_url" {
  description = "The URL of the slack notifier ECR repository"
  value       = module.ecr_slack_notifier.repository_url
}

output "ecr_slack_notifier_repository_name" {
  description = "The name of the slack notifier ECR repository"
  value       = module.ecr_slack_notifier.repository_name
}

# =============================================================================
# S3 Outputs
# =============================================================================

output "s3_resources_bucket_name" {
  description = "The name of the resources S3 bucket"
  value       = module.s3_resources.bucket_name
}

output "s3_resources_bucket_arn" {
  description = "The ARN of the resources S3 bucket"
  value       = module.s3_resources.bucket_arn
}

# =============================================================================
# IAM Outputs
# =============================================================================

output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}
