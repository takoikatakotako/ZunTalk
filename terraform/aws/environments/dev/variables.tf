variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "slack_notifier_image_uri" {
  description = "ECR image URI for slack notifier Lambda"
  type        = string
}
