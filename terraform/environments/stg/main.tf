data "aws_ecr_repository" "backend" {
  name = "zuntalk-backend"
}

module "lambda" {
  source = "../../modules/lambda"

  function_name = "zuntalk-backend-stg"
  image_uri     = "${data.aws_ecr_repository.backend.repository_url}:stg-latest"
  timeout       = 30
  memory_size   = 512

  environment_variables = {
    OPENAI_API_KEY = var.openai_api_key
    PORT           = "8080"
    ENV            = "stg"
  }

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
