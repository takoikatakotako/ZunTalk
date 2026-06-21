data "aws_ecr_repository" "backend" {
  name = "zuntalk-backend"
}

locals {
  openai_api_key_parameter_name = "/zuntalk/stg/openai-api-key"
}

resource "aws_ssm_parameter" "openai_api_key" {
  name             = local.openai_api_key_parameter_name
  description      = "OpenAI API key for ZunTalk stg backend"
  type             = "SecureString"
  tier             = "Standard"
  value_wo         = "replace-with-real-openai-api-key"
  value_wo_version = 1
}

module "lambda" {
  source = "../../modules/lambda"

  function_name = "zuntalk-backend-stg"
  image_uri     = "${data.aws_ecr_repository.backend.repository_url}:stg-latest"
  timeout       = 30
  memory_size   = 512

  environment_variables = {
    OPENAI_API_KEY = "ssm://${aws_ssm_parameter.openai_api_key.name}"
    PORT           = "8080"
    ENV            = "stg"
  }

  ssm_parameter_arns = [
    aws_ssm_parameter.openai_api_key.arn
  ]

  log_retention_days = 14

  enable_function_url    = true
  function_url_auth_type = "NONE"

  cors_allow_credentials = true
  cors_allow_origins     = ["*"]
  cors_allow_methods     = ["*"]
  cors_allow_headers     = ["*"]

  tags = {
    Name = "zuntalk-backend-stg"
  }
}
