module "lambda" {
  source = "../../modules/lambda"

  function_name = "zuntalk-backend-prod"
  image_uri     = "448049807848.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:22849bb1c0b0fd687e56fb5f038b3eefce3873ec"
  timeout       = 30
  memory_size   = 512

  environment_variables = {
    OPENAI_API_KEY = var.openai_api_key
    PORT           = "8080"
    ENV            = "prod"
  }

  log_retention_days = 7

  enable_function_url    = true
  function_url_auth_type = "NONE"

  cors_allow_credentials = true
  cors_allow_origins     = ["*"]
  cors_allow_methods     = ["*"]
  cors_allow_headers     = ["*"]

  tags = {
    Name = "zuntalk-backend-prod"
  }
}
