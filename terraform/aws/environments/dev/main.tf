# =============================================================================
# Lambda Functions
# =============================================================================

locals {
  openai_api_key_parameter_name    = "/zuntalk/dev/openai-api-key"
  slack_webhook_url_parameter_name = "/zuntalk/dev/slack-webhook-url"
}

resource "aws_ssm_parameter" "openai_api_key" {
  name             = local.openai_api_key_parameter_name
  description      = "OpenAI API key for ZunTalk dev backend"
  type             = "SecureString"
  tier             = "Standard"
  value_wo         = "replace-with-real-openai-api-key"
  value_wo_version = 1
}

resource "aws_ssm_parameter" "slack_webhook_url" {
  name             = local.slack_webhook_url_parameter_name
  description      = "Slack webhook URL for ZunTalk dev error notifications"
  type             = "SecureString"
  tier             = "Standard"
  value_wo         = "replace-with-real-slack-webhook-url"
  value_wo_version = 1
}

# バックエンドAPI
module "lambda_backend" {
  source = "../../modules/lambda"

  function_name = "zuntalk-backend-dev"
  image_uri     = "448049807848.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:22849bb1c0b0fd687e56fb5f038b3eefce3873ec"
  timeout       = 30
  memory_size   = 512

  environment_variables = {
    OPENAI_API_KEY = "ssm://${aws_ssm_parameter.openai_api_key.name}"
    PORT           = "8080"
    ENV            = "dev"
  }

  ssm_parameter_arns = [
    aws_ssm_parameter.openai_api_key.arn
  ]

  log_retention_days = 7

  enable_function_url    = true
  function_url_auth_type = "NONE"

  cors_allow_credentials = true
  cors_allow_origins     = ["*"]
  cors_allow_methods     = ["*"]
  cors_allow_headers     = ["*"]

  tags = {
    Name = "zuntalk-backend-dev"
  }
}

# Slack通知用Lambda
module "lambda_slack_notifier" {
  source = "../../modules/lambda"

  function_name = "zuntalk-slack-notifier-dev"
  image_uri     = var.slack_notifier_image_uri
  timeout       = 30
  memory_size   = 128

  environment_variables = {
    SLACK_WEBHOOK_URL = "ssm://${aws_ssm_parameter.slack_webhook_url.name}"
  }

  ssm_parameter_arns = [
    aws_ssm_parameter.slack_webhook_url.arn
  ]

  log_retention_days = 7

  enable_function_url = false

  tags = {
    Name = "zuntalk-slack-notifier-dev"
  }
}

# =============================================================================
# CloudWatch Logs Subscription Filter
# =============================================================================

# バックエンドログのエラー検知
module "logs_filter_backend" {
  source = "../../modules/logs-subscription-filter"

  name                   = "zuntalk-backend-dev-error-filter"
  log_group_name         = module.lambda_backend.log_group_name
  log_group_arn          = module.lambda_backend.log_group_arn
  filter_pattern         = "ERROR"
  destination_lambda_arn = module.lambda_slack_notifier.function_arn
}
