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

# GitHub Actions OIDC thumbprint
# AWSは2023年7月以降、GitHub ActionsのOIDCプロバイダーについてthumbprintを検証しなくなった
# ただしTerraformのaws_iam_openid_connect_providerは必須パラメータのため設定が必要
variable "github_oidc_thumbprint" {
  description = "GitHub Actions OIDC provider thumbprint (not validated by AWS since July 2023)"
  type        = string
}
