# =============================================================================
# Lambda Outputs - Backend
# =============================================================================

output "lambda_backend_function_name" {
  description = "The name of the backend Lambda function"
  value       = module.lambda_backend.function_name
}

output "lambda_backend_function_arn" {
  description = "The ARN of the backend Lambda function"
  value       = module.lambda_backend.function_arn
}

output "lambda_backend_function_url" {
  description = "The URL of the backend Lambda function"
  value       = module.lambda_backend.function_url
}

# =============================================================================
# Lambda Outputs - Slack Notifier
# =============================================================================

output "lambda_slack_notifier_function_name" {
  description = "The name of the Slack notifier Lambda function"
  value       = module.lambda_slack_notifier.function_name
}

output "lambda_slack_notifier_function_arn" {
  description = "The ARN of the Slack notifier Lambda function"
  value       = module.lambda_slack_notifier.function_arn
}
