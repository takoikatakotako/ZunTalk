module "lambda" {
  source = "../../modules/lambda"

  function_name = "zuntalk-backend-dev"
  image_uri     = "448049807848.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:22849bb1c0b0fd687e56fb5f038b3eefce3873ec"
  timeout       = 30
  memory_size   = 512

  environment_variables = {
    OPENAI_API_KEY = var.openai_api_key
    PORT           = "8080"
    ENV            = "dev"
  }

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

module "slack_notifier" {
  source = "../../modules/lambda"

  function_name = "zuntalk-slack-notifier-dev"
  image_uri     = var.slack_notifier_image_uri
  timeout       = 30
  memory_size   = 128

  environment_variables = {
    SLACK_WEBHOOK_URL = var.slack_webhook_url
  }

  log_retention_days = 7

  enable_function_url = false

  tags = {
    Name = "zuntalk-slack-notifier-dev"
  }
}

module "backend_log_filter" {
  source = "../../modules/logs-subscription-filter"

  name                   = "zuntalk-backend-dev-error-filter"
  log_group_name         = module.lambda.log_group_name
  log_group_arn          = module.lambda.log_group_arn
  filter_pattern         = "ERROR"
  destination_lambda_arn = module.slack_notifier.function_arn
}
