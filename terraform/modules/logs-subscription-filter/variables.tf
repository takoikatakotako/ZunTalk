variable "name" {
  description = "Name of the subscription filter"
  type        = string
}

variable "log_group_name" {
  description = "Name of the CloudWatch Log Group to monitor"
  type        = string
}

variable "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  type        = string
}

variable "filter_pattern" {
  description = "Filter pattern for the subscription filter (e.g., 'ERROR' or '?ERROR ?Exception')"
  type        = string
  default     = "ERROR"
}

variable "destination_lambda_arn" {
  description = "ARN of the Lambda function to receive the log events"
  type        = string
}
