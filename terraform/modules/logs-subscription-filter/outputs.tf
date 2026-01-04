output "subscription_filter_name" {
  description = "Name of the subscription filter"
  value       = aws_cloudwatch_log_subscription_filter.default.name
}
