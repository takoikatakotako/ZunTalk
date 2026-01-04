variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL for error notifications"
  type        = string
  sensitive   = true
}

variable "slack_notifier_image_uri" {
  description = "ECR image URI for slack notifier Lambda"
  type        = string
}
