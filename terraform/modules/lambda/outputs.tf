output "function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.default.function_name
}

output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.default.arn
}

output "invoke_arn" {
  description = "The ARN to be used for invoking Lambda function from API Gateway"
  value       = aws_lambda_function.default.invoke_arn
}

output "function_url" {
  description = "The URL of the Lambda function"
  value       = var.enable_function_url ? aws_lambda_function_url.default[0].function_url : null
}

output "role_arn" {
  description = "The ARN of the IAM role created for the Lambda function"
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "The name of the IAM role created for the Lambda function"
  value       = aws_iam_role.lambda.name
}
